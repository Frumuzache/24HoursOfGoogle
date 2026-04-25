INSERT OR IGNORE INTO user_profiles (
  display_name,
  age,
  disorders,
  calming_strategies,
  favorite_foods,
  hobbies,
  medications,
  emergency_contact_name,
  emergency_contact_phone
)
VALUES (
  'Demo User',
  24,
  '["anxiety disorder"]',
  '["deep breathing", "walk in a quiet park", "listen to instrumental music"]',
  '["bananas", "yogurt"]',
  '["drawing", "journaling"]',
  '["sertraline"]',
  'Alex',
  '+1-555-100-2020'
);
