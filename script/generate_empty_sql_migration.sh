#!/bin/bash

if [ ! -e script/mediawords.sql ]; then
    echo "Can't find script/mediawords.sql.  Are you running from the mediacloud root directory?";
    exit;
fi  

NEW_SCHEMA_VERSION=`cat script/mediawords.sql  \
    | perl -lne 'print if /(MEDIACLOUD_DATABASE_SCHEMA_VERSION CONSTANT INT)/'   \
    | perl -lpe 's/.*MEDIACLOUD_DATABASE_SCHEMA_VERSION CONSTANT INT := (\d+?);.*/$1/'`
    
if [ "$NEW_SCHEMA_VERSION" == '' ] ; then
    echo "Unable to find MEDIACLOUD_DATABASE_SCHEMA_VERSION in mediawords.sql";
    exit;
fi
    
OLD_SCHEMA_VERSION=`expr "$NEW_SCHEMA_VERSION" - 1`

if [ "$OLD_SCHEMA_VERSION" == '' ] ; then
    echo "Unable to generate old schema version from new schema version";
    exit;
fi

MIGRATION_FILE="sql_migrations/mediawords-$OLD_SCHEMA_VERSION-$NEW_SCHEMA_VERSION.sql";

if [ -e "$MIGRATION_FILE" ]; then
    echo "'$MIGRATION_FILE' already exists.  Cowardly refusing to overwrite it.";
    exit;
fi

SQL="--
-- This is a Media Cloud PostgreSQL schema difference file (a \"diff\") between schema
-- versions ${OLD_SCHEMA_VERSION} and ${NEW_SCHEMA_VERSION}.
--
-- If you are running Media Cloud with a database that was set up with a schema version
-- ${OLD_SCHEMA_VERSION}, and you would like to upgrade both the Media Cloud and the
-- database to be at version ${NEW_SCHEMA_VERSION}, import this SQL file:
--
--     psql mediacloud < mediawords-${OLD_SCHEMA_VERSION}-${NEW_SCHEMA_VERSION}.sql
--
-- You might need to import some additional schema diff files to reach the desired version.
--
--
-- 1 of 2. Import the output of 'apgdiff':
--

--
-- 2 of 2. Reset the database version.
--

SELECT set_database_schema_version();

"

echo "$SQL" > "$MIGRATION_FILE"

git add "$MIGRATION_FILE"

echo "generated $MIGRATION_FILE and added it to git commit"

