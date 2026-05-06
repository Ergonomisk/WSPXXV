# frozen_string_literal: true

require 'sqlite3'
require 'bcrypt'

# Ansvarar för att skapa och returnera en databasanslutning till SQLite.
# Alla modellklasser använder denna klass för att hämta sin anslutning.
class Database
  # Öppnar och returnerar en anslutning till applikationens SQLite-databas.
  # Aktiverar foreign key-stöd och returnerar resultat som hashar
  # med kolumnnamn som nycklar.
  #
  # @return [SQLite3::Database] en öppen databasanslutning med
  #   results_as_hash och foreign_keys aktiverade
  def self.connection
    db = SQLite3::Database.new('db/databas.db')
    db.results_as_hash = true
    db.execute("PRAGMA foreign_keys = ON")
    db
  end
end

# Hanterar databasoperationer kopplade till användarkonton,
# inklusive sökning, skapande, autentisering och behörighetshantering.
class User
  # Hämtar en användare från databasen baserat på användarnamn.
  #
  # @param name [String] användarnamnet att söka efter
  # @return [Hash, nil] hash med nycklarna 'id', 'name', 'pwd_digest' och
  #   'is_admin', eller nil om användaren inte finns
  def self.find_by_name(name)
    Database.connection.execute(
      "SELECT id, name, pwd_digest, is_admin FROM user WHERE name = ?", name
    ).first
  end

  # Hämtar en användare från databasen baserat på id.
  #
  # @param id [Integer] användarens databas-id
  # @return [Hash, nil] hash med nycklarna 'id', 'name' och 'is_admin',
  #   eller nil om användaren inte finns
  def self.find(id)
    Database.connection.execute(
      "SELECT id, name, is_admin FROM user WHERE id = ?", id.to_i
    ).first
  end

  # Hämtar alla användare, sorterade stigande på id.
  # Används i adminpanelen.
  #
  # @return [Array<Hash>] lista med hashar innehållande 'id', 'name' och 'is_admin'
  def self.all
    Database.connection.execute("SELECT id, name, is_admin FROM user ORDER BY id")
  end

  # Kontrollerar om ett användarnamn redan är registrerat i databasen.
  #
  # @param name [String] användarnamnet att kontrollera
  # @return [Boolean] true om användaren finns, annars false
  def self.exists?(name)
    !Database.connection.execute("SELECT id FROM user WHERE name = ?", name).empty?
  end

  # Skapar en ny användare med ett bcrypt-hashat lösenord.
  # Den nya användaren får standardvärdet is_admin = 0.
  #
  # @param name [String] det önskade användarnamnet
  # @param pwd  [String] lösenordet i klartext som hashas innan lagring
  # @return [void]
  def self.create(name, pwd)
    pwd_digest = BCrypt::Password.create(pwd)
    Database.connection.execute(
      "INSERT INTO user (name, pwd_digest) VALUES (?, ?)", [name, pwd_digest]
    )
  end

  # Autentiserar en användare genom att jämföra det angivna lösenordet
  # mot det lagrade bcrypt-hashet.
  #
  # @param name [String] användarnamnet
  # @param pwd  [String] lösenordet i klartext
  # @return [Hash, nil] användarens data-hash om autentiseringen lyckas,
  #   annars nil
  def self.authenticate(name, pwd)
    user = find_by_name(name)
    return nil if user.nil?
    return user if BCrypt::Password.new(user['pwd_digest']) == pwd
    nil
  end

  # Uppdaterar en användares lösenord med ett nytt bcrypt-hashat värde.
  #
  # @param id      [Integer] användarens databas-id
  # @param new_pwd [String]  det nya lösenordet i klartext
  # @return [void]
  def self.update_password(id, new_pwd)
    pwd_digest = BCrypt::Password.create(new_pwd)
    Database.connection.execute(
      "UPDATE user SET pwd_digest = ? WHERE id = ?", [pwd_digest, id.to_i]
    )
  end

  # Tar bort en användare permanent från databasen.
  # Alla kopplade player_runs, inventory_items och run_log-poster
  # raderas automatiskt via ON DELETE CASCADE.
  #
  # @param id [Integer] användarens databas-id
  # @return [void]
  def self.delete(id)
    Database.connection.execute("DELETE FROM user WHERE id = ?", id.to_i)
  end

  # Sätter eller tar bort adminbehörighet för en användare.
  #
  # @param id       [Integer] användarens databas-id
  # @param is_admin [Boolean] true för att ge adminbehörighet, false för att ta bort den
  # @return [void]
  def self.set_admin(id, is_admin)
    Database.connection.execute(
      "UPDATE user SET is_admin = ? WHERE id = ?", [is_admin ? 1 : 0, id.to_i]
    )
  end
end

# Hanterar databasoperationer för äventyren i spelet.
class Adventure
  # Hämtar alla tillgängliga äventyr sorterade stigande på id.
  #
  # @return [Array<Hash>] lista med alla äventyr som hashar
  def self.all
    Database.connection.execute("SELECT * FROM adventurename ORDER BY id")
  end

  # Söker efter äventyr vars namn matchar en sökfras (skiftlägesokänslig delsökning).
  #
  # @param query [String] söksträngen att matcha mot äventyrens namn
  # @return [Array<Hash>] lista med matchande äventyr som hashar
  def self.search(query)
    Database.connection.execute(
      "SELECT * FROM adventurename WHERE name LIKE ?", "%#{query}%"
    )
  end

  # Hämtar ett specifikt äventyr baserat på dess id.
  #
  # @param id [Integer, String] äventyrets databas-id
  # @return [Hash, nil] äventyrets data som hash, eller nil om det inte finns
  def self.find(id)
    Database.connection.execute(
      "SELECT * FROM adventurename WHERE id = ?", id.to_i
    ).first
  end
end

# Hanterar databasoperationer för rum inom ett äventyr.
class Room
  # Hämtar det första rummet i ett äventyr, sorterat på room_order stigande.
  #
  # @param adventure_id [Integer] id för det äventyr vars första rum ska hämtas
  # @return [Hash, nil] rummets data som hash, eller nil om inga rum finns
  def self.first_in_adventure(adventure_id)
    Database.connection.execute(
      "SELECT * FROM arooms WHERE adventure_id = ? ORDER BY room_order ASC LIMIT 1",
      adventure_id
    ).first
  end

  # Hämtar ett specifikt rum baserat på dess id.
  #
  # @param id [Integer] rummets databas-id
  # @return [Hash, nil] rummets data som hash, eller nil om det inte finns
  def self.find(id)
    Database.connection.execute("SELECT * FROM arooms WHERE id = ?", id).first
  end

  # Hämtar nästa rum i ett äventyr baserat på aktuell ordningsposition.
  # Nästa rum definieras som det rum vars room_order är exakt ett steg högre.
  #
  # @param adventure_id  [Integer] id för äventyret
  # @param current_order [Integer] nuvarande rums room_order-värde
  # @return [Hash, nil] nästa rums data som hash, eller nil om det är sista rummet
  def self.next_room(adventure_id, current_order)
    Database.connection.execute(
      "SELECT * FROM arooms WHERE adventure_id = ? AND room_order = ?",
      [adventure_id, current_order + 1]
    ).first
  end

  # Räknar antalet rum i ett givet äventyr.
  #
  # @param adventure_id [Integer] id för äventyret
  # @return [Integer] antalet rum i äventyret
  def self.count_in_adventure(adventure_id)
    Database.connection.execute(
      "SELECT COUNT(*) as c FROM arooms WHERE adventure_id = ?", adventure_id
    ).first['c']
  end
end

# Hanterar databasoperationer för spelarens aktiva och avslutade spelomgångar.
# En PlayerRun representerar en specifik spelares framsteg i ett äventyr.
# Inventory lagras separat i tabellen inventory_items (se klassen Inventory).
class PlayerRun
  # Hämtar en aktiv (ej avslutad) spelomgång för ett givet user_id och äventyr.
  #
  # @param user_id      [Integer] id för den inloggade användaren
  # @param adventure_id [Integer] id för äventyret
  # @return [Hash, nil] spelarens aktiva omgång som hash, eller nil om ingen finns
  def self.find_active(user_id, adventure_id)
    Database.connection.execute(
      "SELECT * FROM player_runs
       WHERE user_id = ? AND adventure_id = ? AND finished = 0",
      [user_id, adventure_id]
    ).first
  end

  # Hämtar alla omgångar för en användare med äventyrsnamn och progressdata.
  # Varje rad innehåller äventyrsnamn, totalt antal rum och aktuell room_order.
  # Returnerar en rad per omgång, sorterad per äventyr och omgångs-id.
  #
  # @param user_id [Integer] id för användaren vars progress ska hämtas
  # @return [Array<Hash>] lista med omgångar berikade med progressdata
  def self.progress_for_user(user_id)
    Database.connection.execute(
      "SELECT pr.*, a.name AS adventure_name,
              (SELECT COUNT(*) FROM arooms WHERE adventure_id = pr.adventure_id) AS total_rooms,
              (SELECT room_order FROM arooms WHERE id = pr.current_room_id) AS current_order
       FROM player_runs pr
       JOIN adventurename a ON a.id = pr.adventure_id
       WHERE pr.user_id = ?
       ORDER BY pr.adventure_id, pr.id DESC",
      user_id
    )
  end

  # Skapar en ny spelomgång och placerar spelaren i det angivna startrummet.
  # Inventory är initialt tomt — föremål läggs till via klassen Inventory.
  #
  # @param user_id      [Integer] id för den inloggade användaren
  # @param adventure_id [Integer] id för äventyret som startas
  # @param first_room_id [Integer] id för det rum spelaren börjar i
  # @return [Hash] den nyskapade spelomgångens data som hash
  def self.create(user_id, adventure_id, first_room_id)
    db = Database.connection
    db.execute(
      "INSERT INTO player_runs (user_id, adventure_id, current_room_id)
       VALUES (?, ?, ?)",
      [user_id, adventure_id, first_room_id]
    )
    db.execute(
      "SELECT * FROM player_runs
       WHERE user_id = ? AND adventure_id = ? AND finished = 0
       ORDER BY id DESC LIMIT 1",
      [user_id, adventure_id]
    ).first
  end

  # Tar bort alla spelomgångar för en given användare och ett äventyr.
  # Kopplade inventory_items och run_log-poster raderas via ON DELETE CASCADE.
  # Används vid omstart av ett äventyr.
  #
  # @param user_id      [Integer] id för användaren
  # @param adventure_id [Integer] id för äventyret vars omgångar ska raderas
  # @return [void]
  def self.delete_for(user_id, adventure_id)
    Database.connection.execute(
      "DELETE FROM player_runs WHERE user_id = ? AND adventure_id = ?",
      [user_id, adventure_id]
    )
  end

  # Hämtar en spelomgång baserat på dess id.
  #
  # @param id [Integer] spelomgångens databas-id
  # @return [Hash, nil] spelomgångens data som hash, eller nil om den inte finns
  def self.find(id)
    Database.connection.execute(
      "SELECT * FROM player_runs WHERE id = ?", id
    ).first
  end

  # Förflyttar spelaren till ett nytt rum genom att uppdatera current_room_id.
  #
  # @param run_id  [Integer] spelomgångens databas-id
  # @param room_id [Integer] id för det rum spelaren ska förflyttas till
  # @return [void]
  def self.move_to_room(run_id, room_id)
    Database.connection.execute(
      "UPDATE player_runs SET current_room_id = ? WHERE id = ?",
      [room_id, run_id]
    )
  end

  # Markerar en spelomgång som avslutad genom att sätta finished = 1.
  #
  # @param run_id [Integer] spelomgångens databas-id
  # @return [void]
  def self.finish(run_id)
    Database.connection.execute(
      "UPDATE player_runs SET finished = 1 WHERE id = ?", run_id
    )
  end
end

# Hanterar spelarens inventory som individuella rader i tabellen inventory_items.
# Varje föremål som spelaren bär representeras av en separat rad kopplad till run_id,
# vilket möjliggör att samma föremål kan förekomma flera gånger.
class Inventory
  # Hämtar alla föremålsnycklar som spelaren bär i en given omgång.
  #
  # @param run_id [Integer] spelomgångens databas-id
  # @return [Array<String>] lista med föremålsnycklar, tom om inventory är tomt
  def self.for_run(run_id)
    Database.connection.execute(
      "SELECT item_key FROM inventory_items WHERE run_id = ?", run_id
    ).map { |row| row['item_key'] }
  end

  # Kontrollerar om spelaren bär på minst en instans av ett givet föremål.
  #
  # @param run_id   [Integer] spelomgångens databas-id
  # @param item_key [String]  föremålets interna nyckel
  # @return [Boolean] true om föremålet finns i inventory, annars false
  def self.has?(run_id, item_key)
    return false if item_key.nil? || item_key.empty?
    !Database.connection.execute(
      "SELECT id FROM inventory_items WHERE run_id = ? AND item_key = ? LIMIT 1",
      [run_id, item_key]
    ).empty?
  end

  # Lägger till ett eller flera föremål i spelarens inventory.
  # Föremål anges som en kommaseparerad sträng, t.ex. "sword,key".
  # Varje föremål sparas som en separat rad i inventory_items.
  #
  # @param run_id    [Integer] spelomgångens databas-id
  # @param items_str [String]  kommaseparerad sträng med föremålsnycklar
  # @return [void]
  def self.add(run_id, items_str)
    return if items_str.nil? || items_str.strip.empty?
    db = Database.connection
    items_str.split(',').map(&:strip).reject(&:empty?).each do |key|
      db.execute(
        "INSERT INTO inventory_items (run_id, item_key) VALUES (?, ?)", [run_id, key]
      )
    end
  end

  # Tar bort den första förekomsten av ett givet föremål från spelarens inventory.
  # Om föremålet förekommer flera gånger tas bara en instans bort.
  #
  # @param run_id   [Integer] spelomgångens databas-id
  # @param item_key [String]  föremålets interna nyckel
  # @return [void]
  def self.remove(run_id, item_key)
    return if item_key.nil? || item_key.empty?
    row = Database.connection.execute(
      "SELECT id FROM inventory_items WHERE run_id = ? AND item_key = ? LIMIT 1",
      [run_id, item_key]
    ).first
    return unless row
    Database.connection.execute(
      "DELETE FROM inventory_items WHERE id = ?", row['id']
    )
  end
end

# Hanterar databasoperationer för handlingar (actions) kopplade till rum.
# En action representerar något spelaren kan göra i ett givet rum.
class Action
  # Hämtar alla handlingar som är tillgängliga i ett givet rum.
  #
  # @param room_id [Integer] rummets databas-id
  # @return [Array<Hash>] lista med alla handlingar i rummet som hashar
  def self.for_room(room_id)
    Database.connection.execute(
      "SELECT * FROM actions WHERE room_id = ?", room_id
    )
  end

  # Hämtar en specifik handling baserat på dess id.
  #
  # @param id [Integer] handlingens databas-id
  # @return [Hash, nil] handlingens data som hash, eller nil om den inte finns
  def self.find(id)
    Database.connection.execute("SELECT * FROM actions WHERE id = ?", id).first
  end
end

# Hanterar databasoperationer för händelseloggen kopplad till en spelomgång.
# Loggen håller reda på vilka handlingar spelaren har utfört och deras resultat.
class RunLog
  # Hämtar id:n för alla handlingar som redan utförts i en spelomgång.
  # Används för att filtrera bort redan genomförda handlingar från vyerna.
  #
  # @param run_id [Integer] spelomgångens databas-id
  # @return [Array<Integer>] lista med databas-id:n för använda handlingar
  def self.used_action_ids(run_id)
    Database.connection.execute(
      "SELECT action_id FROM run_log WHERE run_id = ?", run_id
    ).map { |row| row['action_id'] }
  end

  # Hämtar de senaste loggposterna för en spelomgång, i omvänd kronologisk ordning.
  #
  # @param run_id [Integer] spelomgångens databas-id
  # @param limit  [Integer] maximalt antal poster att returnera (standard: 5)
  # @return [Array<Hash>] lista med loggposter som hashar
  def self.recent(run_id, limit = 5)
    Database.connection.execute(
      "SELECT * FROM run_log WHERE run_id = ? ORDER BY id DESC LIMIT ?",
      [run_id, limit]
    )
  end

  # Skapar en ny loggpost för en utförd handling i en spelomgång.
  # action_name och result_text sparas direkt för att bevara historiken
  # även om handlingens data ändras i framtiden.
  #
  # @param run_id      [Integer] spelomgångens databas-id
  # @param action_id   [Integer] handlingens databas-id
  # @param action_name [String]  handlingens namn vid tidpunkten för utförandet
  # @param result_text [String]  den text som visades för spelaren som resultat
  # @return [void]
  def self.create(run_id, action_id, action_name, result_text)
    Database.connection.execute(
      "INSERT INTO run_log (run_id, action_id, action_name, result_text)
       VALUES (?, ?, ?, ?)",
      [run_id, action_id, action_name, result_text]
    )
  end
end