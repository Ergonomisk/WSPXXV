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
  db.execute('DROP TABLE IF EXISTS player_runs')
  db.execute('DROP TABLE IF EXISTS run_log')
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
              room_order INTEGER NOT NULL,
              name TEXT NOT NULL,
              description TEXT,
              FOREIGN KEY (adventure_id) REFERENCES adventurename(id))')

  # requires_item: item that must be in inventory (NULL = always shown)
  # gives_item: comma-separated items added to inventory (NULL = nothing)
  # removes_item: item removed from inventory (NULL = nothing)
  # moves_to_next: 1 = advances player to next room after this action
  db.execute('CREATE TABLE actions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              room_id INTEGER NOT NULL,
              name TEXT NOT NULL,
              result TEXT,
              requires_item TEXT,
              gives_item TEXT,
              removes_item TEXT,
              moves_to_next INTEGER DEFAULT 0,
              FOREIGN KEY (room_id) REFERENCES arooms(id))')

  # session_token: from Sinatra session, ties run to browser
  # inventory: comma-separated item names e.g. "sword,key"
  db.execute('CREATE TABLE player_runs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              session_token TEXT NOT NULL,
              adventure_id INTEGER NOT NULL,
              current_room_id INTEGER NOT NULL,
              inventory TEXT DEFAULT "",
              finished INTEGER DEFAULT 0)')

  db.execute('CREATE TABLE run_log (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              run_id INTEGER NOT NULL,
              action_id INTEGER NOT NULL,   
              action_name TEXT NOT NULL,
              result_text TEXT,
              timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY (run_id) REFERENCES player_runs(id))')
end

def populate_tables(db)

  # ═══════════════════════════════════════════════════════
  # ADVENTURE 1: Den mörka skogen (5 rooms)
  # ═══════════════════════════════════════════════════════
  db.execute('INSERT INTO adventurename (name, description) VALUES (
    "Den mörka skogen",
    "Du vaknar upp vid kanten av en mystisk skog. Något lockar dig in bland de täta träden. Kan du ta dig igenom levande?")')

  db.execute('INSERT INTO arooms (adventure_id, room_order, name, description) VALUES (1, 1,
    "Skogens ingång",
    "Du står vid skogens kant. Träden är täta och mörka. Ett rostigt svärd ligger i gräset bredvid dig. En stig leder in i mörkret.")')

  db.execute('INSERT INTO arooms (adventure_id, room_order, name, description) VALUES (1, 2,
    "Den dimmiga stigen",
    "Dimma rullar in mellan träden. Du hör ett grymtande i buskarna — en goblin vaktar stigen framåt. Den håller ett trasigt spjut.")')

  db.execute('INSERT INTO arooms (adventure_id, room_order, name, description) VALUES (1, 3,
    "Den gamla brunnen",
    "En övervuxen stenbrunn skymtar i ett litet glänta. Ett rep med hink hänger kvar. På botten glimmar något till.")')

  db.execute('INSERT INTO arooms (adventure_id, room_order, name, description) VALUES (1, 4,
    "Trollets bro",
    "En skakig träbro spänner över en brusande flod. Under bron bor ett fruktansvärt troll som kräver betalning. Du ser ett skelett nära bron med ett guldmynt i fickan.")')

  db.execute('INSERT INTO arooms (adventure_id, room_order, name, description) VALUES (1, 5,
    "Skogens hjärta",
    "Du har nått skogens hjärta! En gigantisk uråldig ek dominerar platsen. En drake sover lindad runt stammen. En glimmande skatt ligger under dess kropp.")')

  # ── Room 1 actions ──────────────────────────────────
  db.execute('INSERT INTO actions (room_id, name, result, gives_item, moves_to_next) VALUES (1,
    "Plocka upp svärdet",
    "Du tar upp det rostiga svärdet. Det är tungt men fortfarande vasst.",
    "sword", 0)')

  db.execute('INSERT INTO actions (room_id, name, result, moves_to_next) VALUES (1,
    "Undersök stigen",
    "Stigen slingrar sig in i mörkret. Du ser gamla fotsteg i leran och hör avlägsna ljud.",
    0)')

  db.execute('INSERT INTO actions (room_id, name, result, moves_to_next) VALUES (1,
    "Gå in i skogen",
    "Du tar ett djupt andetag och kliver in i mörkret. Du hoppas att det inte finns några monster...",
    1)')

  # ── Room 2 actions ──────────────────────────────────
  db.execute('INSERT INTO actions (room_id, name, result, requires_item, removes_item, moves_to_next) VALUES (2,
    "Döda goblinen med svärdet",
    "Du svingar svärdet och besegrar goblinen! Vägen är fri. Svärdet gick sönder i kampen.",
    "sword", "sword", 1)')

  db.execute('INSERT INTO actions (room_id, name, result, moves_to_next) VALUES (2,
    "Smyg förbi goblinen i dimman",
    "Du håller andan och kryper tyst förbi goblinen. Det lyckas!",
    1)')

  db.execute('INSERT INTO actions (room_id, name, result, moves_to_next) VALUES (2,
    "Slåss med bara händerna",
    "Du slåss tappert men goblinen är stark. Du klarar dig undan med en blodig näsa och springer förbi.",
    1)')

  # ── Room 3 actions ──────────────────────────────────
  db.execute('INSERT INTO actions (room_id, name, result) VALUES (3,
    "Titta ner i brunnen",
    "Något glimmar på botten. Det verkar vara ett guldmynt och kanske något mer.")')

  db.execute('INSERT INTO actions (room_id, name, result, gives_item, moves_to_next) VALUES (3,
    "Hissa upp hinken",
    "Du vevar upp hinken. Inuti ligger ett blankpolerat guldmynt och en gammal nyckel!",
    "gold_coin,key", 1)')

  db.execute('INSERT INTO actions (room_id, name, result, moves_to_next) VALUES (3,
    "Hoppa ner i brunnen",
    "Det var inte klokt. Du klättrar tillbaka upp, blöt och tom-händad.",
    1)')

  db.execute('INSERT INTO actions (room_id, name, result, requires_item, removes_item) VALUES (3,
    "Drick hälsodrycken",
    "Du dricker den grönaktiga vätskan. Den smakar fruktansvärt men du känner dig omedelbart bättre!",
    "health_potion", "health_potion")')

  # ── Room 4 actions ──────────────────────────────────
  db.execute('INSERT INTO actions (room_id, name, result) VALUES (4,
    "Prata med trollet",
    "Trollet råmar: ETT MYNT ELLER DU GÅR INTE FÖRBI! Du behöver ett guldmynt.")')

  db.execute('INSERT INTO actions (room_id, name, result, gives_item) VALUES (4,
    "Ta guldmyntet från skelettet",
    "Du stoppar ner guldmyntet i fickan. Det känns lite obehagligt men vad som helst för att passera.",
    "gold_coin")')

  db.execute('INSERT INTO actions (room_id, name, result, requires_item, removes_item, moves_to_next) VALUES (4,
    "Ge trollet guldmyntet",
    "Trollet sniffar på myntet, ler brett och kliver åt sidan. Du passerar tryggt!",
    "gold_coin", "gold_coin", 1)')

  db.execute('INSERT INTO actions (room_id, name, result, moves_to_next) VALUES (4,
    "Försök smyga över bron",
    "Bron knarrar högt! Trollet vaknar och jagar dig men du är snabbare och tar dig precis över!",
    1)')

  # ── Room 5 actions ──────────────────────────────────
  db.execute('INSERT INTO actions (room_id, name, result) VALUES (5,
    "Betrakta draken",
    "Draken andas tungt i sin sömn. Eld puffar ur näsborrarna med varje utandning. Den är enorm.")')

  db.execute('INSERT INTO actions (room_id, name, result) VALUES (5,
    "Ta en skattebiten",
    "Du sträcker dig mot skatten. Draken öppnar ett öga och STIRRAR på dig. Du fryser. Den stänger ögat igen. Du tar ett guldsmycke och springer!")')

  db.execute('INSERT INTO actions (room_id, name, result, requires_item, removes_item, gives_item) VALUES (5,
    "Öppna den låsta kistan med nyckeln",
    "Du hittar en gammal kista bakom eken. Din nyckel passar! Inuti ligger ett magiskt svärd som glöder i mörkret. Du är en legend!",
    "key", "key", "magic_sword")')

  db.execute('INSERT INTO actions (room_id, name, result, requires_item) VALUES (5,
    "Visa upp det magiska svärdet för draken",
    "Draken öppnar ögonen och böjer huvudet i respekt. Det verkar som att det magiska svärdet har en koppling till detta väsen...",
    "magic_sword")')


  # ═══════════════════════════════════════════════════════
  # ADVENTURE 2: Det gamla slottet (5 rooms)
  # ═══════════════════════════════════════════════════════
  db.execute('INSERT INTO adventurename (name, description) VALUES (
    "Det gamla slottet",
    "Ett förfallet slott reser sig ur dimman. Ryktet säger att en ond magiker håller en prinsessa fången inne. Vågar du ge dig in?")')

  db.execute('INSERT INTO arooms (adventure_id, room_order, name, description) VALUES (2, 1,
    "Slottsporten",
    "En massiv järnport blockerar ingången. Den är lätt på glänt. På marken ligger en rostig nyckel och en halvfull flaska olja.")')

  db.execute('INSERT INTO arooms (adventure_id, room_order, name, description) VALUES (2, 2,
    "Ingångshallen",
    "En dammig hall med rustningar längs väggarna. En av rustningarna verkar hålla ett svärd. Trappor leder upp och ner.")')

  db.execute('INSERT INTO arooms (adventure_id, room_order, name, description) VALUES (2, 3,
    "Bibliotekets ruiner",
    "Böcker och pergament är utspridda överallt. En trollformel verkar hälften ifylld på ett skrivbord. En besvärjelsepinne glimmar på en hylla.")')

  db.execute('INSERT INTO arooms (adventure_id, room_order, name, description) VALUES (2, 4,
    "Vaktrummets korridor",
    "Två gigantiska stenskulpturer flankerar dörren till tornet. De verkar levande. En inskription på väggen lyder: Bara magi kan passera.")')

  db.execute('INSERT INTO arooms (adventure_id, room_order, name, description) VALUES (2, 5,
    "Mageens torn",
    "Du har nått toppen! En gammal magiker med långa vita kläder vänder sig om. Prinsessan är inlåst i ett bur av ljus. Magikern ler elakt.")')

  # Room 1 actions (Slottsporten)
  db.execute('INSERT INTO actions (room_id, name, result, gives_item) VALUES (6,
    "Ta upp den rostiga nyckeln",
    "Du stoppar ner nyckeln i fickan. Den verkar passa ett gammalt lås.",
    "rusty_key")')

  db.execute('INSERT INTO actions (room_id, name, result, gives_item) VALUES (6,
    "Ta flaskan med olja",
    "Du tar oljeflaskan. Den kan vara användbar för knarriga gångjärn.",
    "oil")')

  db.execute('INSERT INTO actions (room_id, name, result, moves_to_next) VALUES (6,
    "Kryp in genom den öppna porten",
    "Du smyger in genom glipan. Inuti luktar det gammalt och dammigt.",
    1)')

  # Room 2 actions (Ingångshallen)
  db.execute('INSERT INTO actions (room_id, name, result, requires_item, moves_to_next) VALUES (7,
    "Smörj rustningens leder med oljan",
    "Du smörjer den knarriga rustningen. Den öppnar sig och avslöjar ett skarpt svärd!",
    "oil", 0)')

  db.execute('INSERT INTO actions (room_id, name, result, requires_item, gives_item) VALUES (7,
    "Ta svärdet ur den oljesmorda rustningen",
    "Du tar det skarpa svärdet ur rustningen. Det känns balanserat och kraftfullt.",
    "oil", "castle_sword")')

  db.execute('INSERT INTO actions (room_id, name, result, moves_to_next) VALUES (7,
    "Gå uppför trapporna",
    "Du klättrar uppför den knarriga stentrappan mot biblioteket.",
    1)')

  # Room 3 actions (Biblioteket)
  db.execute('INSERT INTO actions (room_id, name, result, gives_item) VALUES (8,
    "Ta besvärjelsepinnen",
    "Du tar den glödande pinnen. Den vibrerar i din hand och känns magisk.",
    "wand")')

  db.execute('INSERT INTO actions (room_id, name, result, requires_item, gives_item) VALUES (8,
    "Slutför trollformeln med besvärjelsepinnen",
    "Du ritar de saknade symbolerna med pinnen. Formuläret lyser upp och du lär dig en kraftfull skyddszauber!",
    "wand", "shield_spell")')

  db.execute('INSERT INTO actions (room_id, name, result, moves_to_next) VALUES (8,
    "Fortsätt mot tornet",
    "Du lämnar bibliotekets kaos och går mot vaktkorridoren.",
    1)')

  # Room 4 actions (Vaktrummets korridor)
  db.execute('INSERT INTO actions (room_id, name, result) VALUES (9,
    "Försök gå förbi statyerna",
    "Statyerna vaknar till liv och blockerar din väg! Du behöver magi för att passera.")')

  db.execute('INSERT INTO actions (room_id, name, result, requires_item, moves_to_next) VALUES (9,
    "Använd skyddszaubern mot statyerna",
    "Du kastar zaubern! Statyerna fryser till is och faller i bitar. Vägen är fri!",
    "shield_spell", 1)')

  db.execute('INSERT INTO actions (room_id, name, result, requires_item, moves_to_next) VALUES (9,
    "Peka besvärjelsepinnen på statyerna",
    "Pinnen skickar ut ett blixt av ljus! Statyerna splittras. Du passerar!",
    "wand", 1)')

  # Room 5 actions (Mageens torn)
  db.execute('INSERT INTO actions (room_id, name, result) VALUES (10,
    "Prata med magikern",
    "Magikern skrattar: Du kan aldrig besegra mig! Inte utan ett riktigt vapen och magi!")')

  db.execute('INSERT INTO actions (room_id, name, result, requires_item, removes_item) VALUES (10,
    "Anfalla magikern med svärdet",
    "Du svingar svärdet! Magikern blockerar med magi men tvingas backa. Svärdet smälter av magikers kraft.",
    "castle_sword", "castle_sword")')

  db.execute('INSERT INTO actions (room_id, name, result, requires_item, gives_item) VALUES (10,
    "Avsluta magikern med besvärjelsepinnen",
    "Du riktar pinnen mot den försvagade magikern och kastar allt du har. Han förvandlas till rök! Prinsessan är fri! Du är en hjälte!",
    "wand", "victory")')

  db.execute('INSERT INTO actions (room_id, name, result) VALUES (10,
    "Befria prinsessan",
    "Du försöker ta dig igenom ljusburen men det är omöjligt utan att besegra magikern först.")')
end

seed!(db)
