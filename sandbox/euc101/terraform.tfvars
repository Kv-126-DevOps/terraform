vpc_id = {
  euc101 = "vpc-0d14e4956bccdc439"
}

rabbitmq_create = {
  euc101 = true
}

subnet_id = {
  euc101 = "subnet-0ad013438ee134ad6"
}

route_53_private_zone_name = {
  euc101 = "private-kv126.pp.ua"
}

# database and objects creation
inputs = {

  # parameters used for creating a database named 'postgres' and for creating objects in the public schema
  db_schema_name = "public"
  db_name        = "postgres"
  db_admin       = "dbuser"   # owner of the database
  extensions     = []

  # install extensions if needed
  #extensions = ["pgaudit"]

 # ---------------------------------- ROLES ------------------------------------------------------------------------------------
  # - "app_admin_role" will be the role used for creation, deletion, grant operations on objects, especially for tables.
  # - "app_write_role" for write operations. If you have a backend that insert lines into tables, it will used a user that inherits permissions from it.
  # Note : "write" role does not have the permissions to create table.
  # Note : the 'createrole' field is a boolean that provides a way to create other roles and put grants on it. Be carefull when you give this permission (privilege escalation).
  db_roles = [
    { id = "admin", role = "app_admin_role", inherit = true, login = false, validity = "infinity", privileges = ["USAGE", "CREATE"], createrole = true },
    { id = "write", role = "app_write_role", inherit = true, login = false, validity = "infinity", privileges = ["USAGE"], createrole = false },
  ],

 # ---------------------------------- GRANT PERMISSIONS ON ROLES ------------------------------------------------------------------------------------
  db_grants = [
    # role app_admin_role : define grants to apply on db 'postgres', schema 'public'
    { object_type = "database", privileges = ["CREATE", "CONNECT", "TEMPORARY"], objects = [],  role = "app_admin_role", owner_role = "postgres", grant_option = true },
    { object_type = "type", privileges = ["USAGE"], objects = [], role = "app_admin_role", owner_role = "postgres", grant_option = true },

    # role app_write_role : define grant to apply on db 'postgres', schema 'public'
    { object_type = "database", privileges = ["CONNECT"], objects = [], role = "app_write_role", owner_role = "app_admin_role", grant_option = false },
    { object_type = "type", privileges = ["USAGE"], objects = [], role = "app_write_role", owner_role = "app_admin_role", grant_option = true },
    { object_type = "table", privileges = ["SELECT", "REFERENCES", "TRIGGER", "INSERT", "UPDATE", "DELETE"], objects = [], role = "app_write_role", owner_role = "app_admin_role", grant_option = false },
    { object_type = "sequence", privileges = ["SELECT", "USAGE"], objects = [], role = "app_write_role", owner_role = "app_admin_role", grant_option = false },
    { object_type = "function", privileges = ["EXECUTE"], objects = [], role = "app_write_role", owner_role = "app_admin_role", grant_option = false },

  ],
 # ---------------------------------- USER  ------------------------------------------------------------------------------------
  db_users = [
    { name = "dbadmin", inherit = true, login = true, membership = ["app_admin_role"], validity = "infinity", connection_limit = -1, createrole = false },
    { name = "dbuser", inherit = true, login = true, membership = ["app_write_role"], validity = "infinity", connection_limit = -1, createrole = false },
  ]
}