require 'sqlite3'

db = SQLite3::Database.new("databas.db")

def seed!(db)
  puts "🧹 Dropping old tables..."
  drop_tables(db)
  puts "🧱 Creating tables..."
  create_tables(db)
  puts "🍎 Populating tables..."
  populate_tables(db)
  puts "✅ Done seeding the database!"
end

def drop_tables(db)
  db.execute('DROP TABLE IF EXISTS adventurename')
  db.execute('DROP TABLE IF EXISTS user')
  db.execute('DROP TABLE IF EXISTS arooms')
  db.execute('DROP TABLE IF EXISTS actions')
  db.execute('DROP TABLE IF EXISTS adventure_rooms')
  db.execute('DROP TABLE IF EXISTS room_actions')
end

def create_tables(db)
  db.execute('CREATE TABLE adventurename (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              pic_link TEXT,
              name TEXT NOT NULL,
              description TEXT)')

  db.execute('CREATE TABLE user (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              pwd_digest TEXT NOT NULL)')

  db.execute('CREATE TABLE arooms (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              adventure_id INTEGER NOT NULL,
              name TEXT NOT NULL,
              description TEXT,
              FOREIGN KEY (adventure_id) REFERENCES adventurename(id))')

  db.execute('CREATE TABLE actions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              room_id INTEGER NOT NULL,
              name TEXT NOT NULL,
              result TEXT,
              FOREIGN KEY (room_id) REFERENCES arooms(id))')
end

def populate_tables(db)
  # Adventures
  db.execute('INSERT INTO adventurename (name, description) VALUES ("Äventyr 1", "En mörk skog fylld med mysterier.")')
  db.execute('INSERT INTO adventurename (name, description) VALUES ("Äventyr 2", "Ett gammalt slott med hemliga rum.")')
  db.execute('INSERT INTO adventurename (name, description) VALUES ("Äventyr 3", "En underjordisk grotta med skatter.")')

  # Rooms for Adventure 1 (id=1)
  db.execute('INSERT INTO arooms (adventure_id, name, description) VALUES (1, "Skogens ingång", "Du står vid kanten av en tät skog. Det luktar mossa och fuktig jord.")')
  db.execute('INSERT INTO arooms (adventure_id, name, description) VALUES (1, "Det gamla trädet", "Ett enormt gammalt träd tornar upp sig framför dig. Äpplen hänger i grenarna.")')

  # Rooms for Adventure 2 (id=2)
  db.execute('INSERT INTO arooms (adventure_id, name, description) VALUES (2, "Slottets port", "En massiv järnport blockerar ingången. Den är lätt på glänt.")')
  db.execute('INSERT INTO arooms (adventure_id, name, description) VALUES (2, "Stora salen", "En dammig sal med rustningar längs väggarna och ett stort bord i mitten.")')

  # Actions for room 1 (Skogens ingång)
  db.execute('INSERT INTO actions (room_id, name, result) VALUES (1, "Gå in i skogen", "Du kliver in bland de täta träden...")')
  db.execute('INSERT INTO actions (room_id, name, result) VALUES (1, "Titta runt", "Du ser ett spår i marken som leder norrut.")')

  # Actions for room 2 (Det gamla trädet)
  db.execute('INSERT INTO actions (room_id, name, result) VALUES (2, "Plocka ett äpple", "Du sträcker dig upp och tar ett saftigt äpple. +1 HP!")')
  db.execute('INSERT INTO actions (room_id, name, result) VALUES (2, "Slå på trädet", "Du slår på trädet. Det händer ingenting. Din hand gör ont.")')
  db.execute('INSERT INTO actions (room_id, name, result) VALUES (2, "Fråga trädet om ett äpple", "Trädet svarar inte. Men det känns som att det lyssnar.")')
end

seed!(db)