require "spec"
require "../src/tds"

MASTER = DB.open("/test")
MASTER.exec("CREATE DATABASE test")
