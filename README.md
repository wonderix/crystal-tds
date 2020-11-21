# crystal-tds

TODO: Write a description here

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     crystal-tds:
       github: your-github-user/crystal-tds
   ```

2. Run `shards install`

## Usage

```crystal
require "crystal-tds"
```

`crystal-db` driver for Microsoft SQL Server based on the work of [FreeTDS](https://www.freetds.org/) and [tiny_tds](https://github.com/rails-sqlserver/tiny_tds)

## Development

```bash
brew install freetds
```


## Contributing

1. Fork it (<https://github.com/your-github-user/crystal-tds/fork>)
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