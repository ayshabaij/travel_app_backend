require 'sqlite3'

# Connect to the database
DB = SQLite3::Database.new 'reception_database.db'

# Clear existing records to avoid duplicates (optional)
DB.execute("DELETE FROM hobbies")
DB.execute("DELETE FROM dietary_restrictions")
DB.execute("DELETE FROM accessibilities")

# Seed Hobbies
hobbies = [
  'Swimming', 'Running', 'Art', 'History', 'Gaming', 'Cycling', 'Hiking', 
  'Cooking', 'Photography', 'Yoga', 'Dancing', 'Fishing', 'Bird Watching', 
  'Gardening', 'Traveling', 'Writing', 'Reading', 'Music', 'Fitness', 
  'Rock Climbing', 'Skiing', 'Snowboarding', 'Surfing', 'Scuba Diving', 
  'Martial Arts', 'Pottery', 'Woodworking', 'Knitting', 'Baking', 
  'Tennis', 'Basketball', 'Soccer', 'Volleyball', 'Table Tennis', 
  'Archery', 'Horse Riding', 'Camping', 'Astronomy', 'Chess', 'Golf', 
  'Geocaching', 'Kite Flying', 'Origami', 'Model Building', 
  'Drone Flying', 'Sailing', 'Kayaking', 'Canoeing', 'Wine Tasting', 
  'Astrology', 'Meditation', 'Calligraphy', 'Magic Tricks', 
  'Scrapbooking', 'Metal Detecting', 'Juggling', 'Parkour', 'Bowling', 
  'Lacrosse', 'Rugby', 'Fencing', 'Ice Skating', 'BMX Riding', 
  'Roller Skating', 'Stand-Up Comedy', 'Beer Brewing', 'Cheese Making', 
  'Soap Making'
]

hobbies.each do |hobby|
  DB.execute "INSERT INTO hobbies (name) VALUES (?)", hobby
end

# Seed Dietary Restrictions
dietary_restrictions = [
  'None', 'Nut allergy', 'Gluten-free', 'Dairy-free', 'Halal', 
  'Lactose intolerant', 'Shellfish allergy', 'Soy allergy', 'Kosher', 
  'Egg allergy', 'Seafood allergy', 'Low-sodium', 'Vegan', 'Low-carb', 
  'Low-fat', 'Diabetic', 'Vegetarian', 'No pork', 'Pescatarian', 
  'Paleo', 'Keto', 'FODMAP', 'Organic only', 'Peanut allergy', 
  'Citrus allergy', 'Sulfite allergy', 'Fructose intolerance', 
  'MSG sensitivity', 'Raw food diet', 'Nightshade allergy'
]

dietary_restrictions.each do |restriction|
  DB.execute "INSERT INTO dietary_restrictions (name) VALUES (?)", restriction
end

# Seed Accessibilities
accessibilities = [
  'None', 'Wheelchair user', 'Visual impairment', 'Hearing impairment', 
  'Cognitive disability', 'Autism', 'Dyslexia', 'ADHD', 
  'Mobility impairment', 'Chronic pain', 'Mental health condition', 
  'Speech impairment', 'Epilepsy', "Alzheimer's disease", 
  "Parkinson's disease", 'Down syndrome', 'Chronic illness', 
  'Spinal cord injury', 'Cerebral palsy', 'Muscular dystrophy', 
  'Multiple sclerosis'
]

accessibilities.each do |accessibility|
  DB.execute "INSERT INTO accessibilities (name) VALUES (?)", accessibility
end

puts "Data seeded successfully into hobbies, dietary restrictions, and accessibilities tables."
