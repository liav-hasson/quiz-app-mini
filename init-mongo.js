// =============================================================================
// MongoDB Initialization Script - Quiz App Mini Version
// =============================================================================
// This script runs automatically when MongoDB container starts
// It loads the seed data from db.json into the quizdb database

// Switch to the quiz database
db = db.getSiblingDB('quizdb');

print('=== Initializing Quiz Database ===');

// Load the seed data from the sample data file
const seedData = cat('/docker-entrypoint-initdb.d/sample-data.json');
const data = JSON.parse(seedData);

print('Seed data loaded successfully');
print('Categories found: ' + Object.keys(data).length);

// Transform the JSON structure into MongoDB documents
// Structure: { "Category": { "Subject": { "keywords": [...] } } }
const quizDocuments = [];

for (const [category, subjects] of Object.entries(data)) {
    for (const [subject, content] of Object.entries(subjects)) {
        if (content.keywords && Array.isArray(content.keywords)) {
            quizDocuments.push({
                category: category,
                subject: subject,
                keywords: content.keywords,
                created_at: new Date(),
                updated_at: new Date()
            });
        }
    }
}

print('Transformed ' + quizDocuments.length + ' quiz documents');

// Insert the documents into the quiz_data collection
if (quizDocuments.length > 0) {
    db.quiz_data.insertMany(quizDocuments);
    print('Inserted ' + quizDocuments.length + ' documents into quiz_data collection');
} else {
    print('No quiz documents to insert');
}

// Create indexes for better query performance
db.quiz_data.createIndex({ category: 1 });
db.quiz_data.createIndex({ subject: 1 });
db.quiz_data.createIndex({ category: 1, subject: 1 });
print('Created indexes on quiz_data collection');

// Display statistics
print('=== Database Initialization Complete ===');
print('Database: quizdb');
print('Collection: quiz_data');
print('Total documents: ' + db.quiz_data.countDocuments());
print('Categories: ' + db.quiz_data.distinct('category').length);
print('Subjects: ' + db.quiz_data.distinct('subject').length);
print('=======================================');
