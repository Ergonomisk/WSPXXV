# frozen_string_literal: true

require 'sqlite3'
require 'bcrypt'

# Ansvarar för att skapa och returnera en databasanslutning till SQLite.
# Alla modellklasser använder denna klass för att hämta sin anslutning.
class Database
  # Öppnar och returnerar en anslutning till applikationens SQLite-databas.
  # Resultaten returneras som hash med kolumnnamn som nycklar.
  #
  # @return [SQLite3::Database] en öppen databasanslutning med results_as_hash aktiverat
  def self.connection
    db = SQLite3::Database.new('db/databas.db')
    db.results_as_hash = true
    db
  end
end

# Hanterar databasoperationer kopplade till användarkonton,
# inklusive sökning, skapande och autentisering.
class User
  # Hämtar en användare från databasen baserat på användarnamn.
  #
  # @param name [String] användarnamnet att söka efter
  # @return [Hash, nil] en hash med nycklarna 'id' och 'pwd_digest', eller nil om användaren inte finns
  def self.find_by_name(name)
    Database.connection.execute("SELECT id, pwd_digest FROM user WHERE name = ?", name).first
  end

  # Kontrollerar om ett användarnamn redan är registrerat.
  #
  # @param name [String] användarnamnet att kontrollera
  # @return [Boolean] true om användaren finns, annars false
  def self.exists?(name)
    !Database.connection.execute("SELECT id FROM user WHERE name = ?", name).empty?
  end

  # Skapar en ny användare med ett bcrypt-hashat lösenord.
  #
  # @param name [String] det önskade användarnamnet
  # @param pwd [String] lösenordet i klartext som hashas innan lagring
  # @return [void]
  def self.create(name, pwd)
    pwd_digest = BCrypt::Password.create(pwd)
    Database.connection.execute("INSERT INTO user (name, pwd_digest) VALUES (?, ?)", [name, pwd_digest])
  end

  # Autentiserar en användare genom att jämföra lösenord mot lagrat bcrypt-hash.
  #
  # @param name [String] användarnamnet
  # @param pwd [String] lösenordet i klartext
  # @return [Hash, nil] användarens data-hash om autentiseringen lyckas, annars nil
  def self.authenticate(name, pwd)
    user = find_by_name(name)
    return nil if user.nil?
    return user if BCrypt::Password.new(user['pwd_digest']) == pwd
    nil
  end
end

# Hanterar databasoperationer för äventyren i spelet.
class Adventure
  # Hämtar alla tillgängliga äventyr från databasen.
  #
  # @return [Array<Hash>] en lista med alla äventyr som hashar
  def self.all
    Database.connection.execute("SELECT * FROM adventurename")
  end

  # Söker efter äventyr vars namn matchar en sökfras (skiftlägesokänslig delsökning).
  #
  # @param query [String] söksträngen att matcha mot äventyrens namn
  # @return [Array<Hash>] en lista med matchande äventyr
  def self.search(query)
    Database.connection.execute("SELECT * FROM adventurename WHERE name LIKE ?", "%#{query}%")
  end

  # Hämtar ett specifikt äventyr baserat på dess id.
  #
  # @param id [Integer, String] äventyrets databas-id
  # @return [Hash, nil] äventyrets data som hash, eller nil om det inte finns
  def self.find(id)
    Database.connection.execute("SELECT * FROM adventurename WHERE id = ?", id.to_i).first
  end
end

# Hanterar databasoperationer för rum inom ett äventyr.
class Room
  # Hämtar det första rummet i ett äventyr, sorterat efter room_order.
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
  #
  # @param adventure_id [Integer] id för äventyret
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
class PlayerRun
  # Hämtar en aktiv (ej avslutad) spelomgång för ett givet sessions-token och äventyr.
  #
  # @param token [String] sessionstoken som identifierar spelaren
  # @param adventure_id [Integer] id för äventyret
  # @return [Hash, nil] spelarens aktiva omgång som hash, eller nil om ingen finns
  def self.find_active(token, adventure_id)
    Database.connection.execute(
      "SELECT * FROM player_runs WHERE session_token = ? AND adventure_id = ? AND finished = 0",
      [token, adventure_id]
    ).first
  end

  # Skapar en ny spelomgång med tomt inventory och placerar spelaren i första rummet.
  #
  # @param token [String] sessionstoken som identifierar spelaren
  # @param adventure_id [Integer] id för äventyret som startas
  # @param first_room_id [Integer] id för det rum spelaren börjar i
  # @return [Hash] den nyskapade spelarens omgång som hash
  def self.create(token, adventure_id, first_room_id)
    db = Database.connection
    db.execute(
      "INSERT INTO player_runs (session_token, adventure_id, current_room_id, inventory) VALUES (?, ?, ?, '')",
      [token, adventure_id, first_room_id]
    )
    db.execute(
      "SELECT * FROM player_runs WHERE session_token = ? AND adventure_id = ? AND finished = 0",
      [token, adventure_id]
    ).first
  end

  # Tar bort alla spelomgångar för ett givet token och äventyr.
  # Används vid omstart av ett äventyr.
  #
  # @param token [String] sessionstoken som identifierar spelaren
  # @param adventure_id [Integer] id för äventyret vars omgångar ska raderas
  # @return [void]
  def self.delete_for(token, adventure_id)
    Database.connection.execute(
      "DELETE FROM player_runs WHERE session_token = ? AND adventure_id = ?",
      [token, adventure_id]
    )
  end

  # Hämtar en spelomgång baserat på dess id.
  #
  # @param id [Integer] spelomgångens databas-id
  # @return [Hash, nil] spelomgångens data som hash, eller nil om den inte finns
  def self.find(id)
    Database.connection.execute("SELECT * FROM player_runs WHERE id = ?", id).first
  end

  # Flyttar spelaren till ett nytt rum genom att uppdatera current_room_id.
  #
  # @param run_id [Integer] spelomgångens id
  # @param room_id [Integer] id för det rum spelaren ska förflyttas till
  # @return [void]
  def self.move_to_room(run_id, room_id)
    Database.connection.execute(
      "UPDATE player_runs SET current_room_id = ? WHERE id = ?",
      [room_id, run_id]
    )
  end

  # Markerar en spelomgång som avslutad (finished = 1).
  #
  # @param run_id [Integer] spelomgångens id
  # @return [void]
  def self.finish(run_id)
    Database.connection.execute("UPDATE player_runs SET finished = 1 WHERE id = ?", run_id)
  end

  # Uppdaterar spelarens inventory med en kommaseparerad sträng av föremål.
  #
  # @param run_id [Integer] spelomgångens id
  # @param inventory_str [String] kommaseparerad sträng med föremålsnycklar, t.ex. "sword,key"
  # @return [void]
  def self.update_inventory(run_id, inventory_str)
    Database.connection.execute(
      "UPDATE player_runs SET inventory = ? WHERE id = ?",
      [inventory_str, run_id]
    )
  end
end

# Hanterar databasoperationer för handlingar (actions) kopplade till rum.
class Action
  # Hämtar alla handlingar som är tillgängliga i ett givet rum.
  #
  # @param room_id [Integer] rummets id
  # @return [Array<Hash>] lista med alla handlingar i rummet
  def self.for_room(room_id)
    Database.connection.execute("SELECT * FROM actions WHERE room_id = ?", room_id)
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
# Loggen håller reda på vilka handlingar spelaren har utfört.
class RunLog
  # Hämtar id:n för alla handlingar som redan använts i en spelomgång.
  # Används för att filtrera bort redan genomförda handlingar.
  #
  # @param run_id [Integer] spelomgångens id
  # @return [Array<Integer>] lista med id:n för använda handlingar
  def self.used_action_ids(run_id)
    Database.connection.execute(
      "SELECT action_id FROM run_log WHERE run_id = ?", run_id
    ).map { |row| row['action_id'] }
  end

  # Hämtar de senaste loggposterna för en spelomgång, sorterade i omvänd ordning.
  #
  # @param run_id [Integer] spelomgångens id
  # @param limit [Integer] maximalt antal poster att returnera (standard: 5)
  # @return [Array<Hash>] lista med loggposter som hashar
  def self.recent(run_id, limit = 5)
    Database.connection.execute(
      "SELECT * FROM run_log WHERE run_id = ? ORDER BY id DESC LIMIT ?",
      [run_id, limit]
    )
  end

  # Skapar en ny loggpost för en utförd handling i en spelomgång.
  #
  # @param run_id [Integer] spelomgångens id
  # @param action_id [Integer] handlingens id
  # @param action_name [String] handlingens namn (sparas för historik)
  # @param result_text [String] den text som visades för spelaren som resultat av handlingen
  # @return [void]
  def self.create(run_id, action_id, action_name, result_text)
    Database.connection.execute(
      "INSERT INTO run_log (run_id, action_id, action_name, result_text) VALUES (?, ?, ?, ?)",
      [run_id, action_id, action_name, result_text]
    )
  end
end