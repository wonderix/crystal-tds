# Adventure Works Example

```
docker run -e 'ACCEPT_EULA=Y' -e 'SA_PASSWORD=My-Secret-Pass' -e 'MSSQL_PID=Express' -p 1433:1433  -d chriseaton/adventureworks:light
crystal run main.cr
```
