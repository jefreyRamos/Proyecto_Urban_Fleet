ExUnit.start()

# Crea los directorios y limpia datos antes de ejecutar cualquier prueba
File.mkdir_p!("data")
File.rm_rf!("data/users.dat")
File.rm_rf!("data/results.log")
File.write!("data/users.dat", "")
File.write!("data/results.log", "")
