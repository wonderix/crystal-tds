# crystal-tds

A crystal native database driver for Microsoft SQL Server. 

![spec](https://github.com/wonderix/crystal-tds/workflows/crystal-tds/badge.svg)

The [C implementation (freetds)](https://www.freetds.org/), the [ the Java implementation (jTDS)](https://github.com/milesibastos/jTDS) but also the Wiresharp Protocol Plugin for TDS were a real treasure trove for the realization of this project.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     crystal-tds:
       github: wonderix/crystal-tds
   ```

2. Run `shards install`

## Usage


This driver now uses the `crystal-db` project. Documentation on connecting,
querying, etc, can be found at:

* https://crystal-lang.org/docs/database/
* https://crystal-lang.org/docs/database/connection_pool.html

## Supported data types

* TINYINT
* SMALLINT
* INT
* BIGINT
* DECIMAL
* NUMERIC
* FLOAT
* REAL
* VARCHAR
* NVARCHAR
* DATE
* DATETIME
* DATETIME2
* SMALLDATETIME
* TEXT
* NTEXT

## Restriction


Have a look at the [issue tracker](https://github.com/wonderix/crystal-tds/labels/restriction) to get an overview over all restrictions.

## Development

* Install Docker


## Contributing

1. Fork it (<https://github.com/wonderix/crystal-tds/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Ulrich Kramer](https://github.com/wonderix) - creator and maintainer


## Testing

```bash
docker run -e 'ACCEPT_EULA=Y' -e 'SA_PASSWORD=My-Secret-Pass' -e 'MSSQL_PID=Express' -p 1433:1433 -d mcr.microsoft.com/mssql/server
crystal spec
```