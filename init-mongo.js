// =============================================================================
// Manual MongoDB Data Loading Script
// =============================================================================
// This script transforms and loads data from sample-data.json into MongoDB
// 
// Usage:
//   1. Copy the DB and the script to the mongo container:
//      docker cp sample-data.json quiz-mongodb:/tmp/sample-data.json
//      docker cp init-mongo.js quiz-mongodb:/tmp/init-mongo.js
//   
//   2. Run this script:
//      docker exec quiz-mongodb mongosh quizdb /tmp/init-mongo.js
// =============================================================================

// Switch to quizdb database
db = db.getSiblingDB('quizdb');

print('=== Starting Manual Data Load ===');

// Load the JSON file
const fs = require('fs');
let data;

try {
    const rawData = fs.readFileSync('/tmp/sample-data.json', 'utf8');
    data = JSON.parse(rawData);
    print('✓ Loaded sample-data.json');
} catch (e) {
    print('ERROR: Could not load sample-data.json');
    print('Make sure to copy it first: docker cp sample-data.json quiz-mongodb:/tmp/');
    quit(1);
}

// Clear existing data
print('\n--- Clearing existing quiz_data collection ---');
const deleteResult = db.quiz_data.deleteMany({});
print(`Deleted ${deleteResult.deletedCount} existing documents`);

// Example document structure:
// {
//     _id: ObjectId("..."),
//     category: "Containers",
//     subject: "Docker Commands",
//     keywords: ["docker run", "docker ps", "docker stop"...],
//     style_modifiers: ["command syntax", "practical command"...],
//     created_at: ISODate("2025-11-14T..."),
//     updated_at: ISODate("2025-11-14T...")
// }
print('\n--- Transforming and inserting data ---');

const documents = [];
let categoryCount = 0;
let subjectCount = 0;

for (const [category, subjects] of Object.entries(data)) {
    categoryCount++;
    print(`\nCategory: ${category}`);
    
    for (const [subject, content] of Object.entries(subjects)) {
        subjectCount++;
        
        if (content.keywords && Array.isArray(content.keywords)) {
            const doc = {
                topic: category,                 // Backend uses 'topic' not 'category'
                subtopic: subject,               // Backend uses 'subtopic' not 'subject'
                keywords: content.keywords,
                style_modifiers: content.style_modifiers || [],
                created_at: new Date(),
                updated_at: new Date()
            };
            
            documents.push(doc);
            print(`  - ${subject}: ${content.keywords.length} keywords, ${doc.style_modifiers.length} style_modifiers`);
        }
    }
}

print(`\n--- Inserting ${documents.length} documents ---`);

if (documents.length > 0) {
    const insertResult = db.quiz_data.insertMany(documents);
    print(`✓ Successfully inserted ${insertResult.insertedIds.length} documents`);
} else {
    print('ERROR: No documents to insert!');
    quit(1);
}

// Create indexes for better query performance
print('\n--- Creating indexes ---');
db.quiz_data.createIndex({ category: 1 });
db.quiz_data.createIndex({ subject: 1 });
db.quiz_data.createIndex({ category: 1, subject: 1 });
print('✓ Indexes created');

// Verify the data
print('\n=== Verification ===');
print(`Total documents: ${db.quiz_data.countDocuments()}`);
print(`Total categories: ${categoryCount}`);
print(`Total subjects: ${subjectCount}`);

print('\nCategories in database:');
const categories = db.quiz_data.distinct('topic');
categories.forEach(cat => {
    const count = db.quiz_data.countDocuments({ topic: cat });
    print(`  - ${cat}: ${count} subjects`);
});

// Show a sample document
print('\nSample document:');
printjson(db.quiz_data.findOne());

// Create test user for development
print('\n--- Creating test user for development ---');
try {
    const userResult = db.users.insertOne({
        google_id: "dev-user-local",
        email: "dev@localhost",
        name: "Local Developer",
        email_verified: true,
        exp: 0,
        questions_count: 0,
        created_at: new Date(),
        updated_at: new Date()
    });
    print('✓ Test user created with email: dev@localhost');
} catch (e) {
    print('WARNING: Failed to create test user: ' + e.message);
}

print('\n=== Data Load Complete! ===');
