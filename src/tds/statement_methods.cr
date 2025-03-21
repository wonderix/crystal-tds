require "string_scanner"
require "./type_info"
require "./utf16_io"

module TDS
  module StatementMethods
    abstract def requestType : RpcRequest::Type

    def perform_query(args : Enumerable) : DB::ResultSet
      statement, parameters = parameterize(args)
      conn.send(PacketIO::Type::RPC) do |io|
        RpcRequest.new(id: requestType, parameters: parameters).write(io)
      end
      result = nil
      conn.recv(PacketIO::Type::REPLY) do |io|
        result = ResultSet.new(self, Token.each(io))
      end
      result.not_nil!
    rescue ex : IO::Error
      raise DB::ConnectionLost.new(conn, ex)
    end

    def perform_exec(args : Enumerable) : DB::ExecResult
      statement, parameters = parameterize(args)
      conn.send(PacketIO::Type::RPC) do |io|
        RpcRequest.new(id: requestType, parameters: parameters).write(io)
      end
      conn.recv(PacketIO::Type::REPLY) do |io|
        Token.each(io) { |t| }
      end
      DB::ExecResult.new 0, 0
    rescue ex : IO::Error
      raise DB::ConnectionLost.new(conn, ex)
    end

    abstract def parameterize(args : Enumerable) : {String, Array(Parameter)}

    # Replaces `?` placeholders with `@Pn` where n = 0..n placeholders in the
    # given SQL statement, returning the updated statement, and array of
    # parameter names and types to be passed to `sp_prepare` or `sp_executesql`
    def parameterize(command : String, arguments : Array(Parameter)) : {String, Array(String), Array(Parameter)}
      index, names, parameters, reordered_arguments = 0, Hash(String, String).new, Array(String).new, Array(Parameter).new(arguments.size)
      unnamed_params_found, named_params_found = false, false
      statement = String.build(command.size) do |string|
        scanner = StringScanner.new(command)
        until scanner.eos?
          case
          when value = scanner.scan(/\[([^\]]|\]\])*\]/) # bracket quoted value, including escaped right brackets such as `]]`
          when value = scanner.scan(/'([^']|'')*'/)      # single quoted value, including escaped single-quotes such as `''`
          when value = scanner.scan(/"([^"]|"")*"/)      # double quoted value, including escaped double-quotes such as `""`
          when value = scanner.scan(/--.*/)              # single line comment
          when comment_start = scanner.scan(/\/\*/)      # multi-line comment
            if comment_end = scanner.scan(/.*?\*\//m)
              value = comment_start + comment_end
            else
              value = comment_start + scanner.rest
              scanner.terminate
            end
          when unnamed_param = scanner.scan('?') # unnamed parameter placeholder
            index += 1
            value = "@PARAM_CRYSTAL_TDS_$#{index}__"
            parameters << "#{value} #{arguments[index - 1].type_info.type}"
            unnamed_params_found = true
          when named_param = scanner.scan(/\$\d+/) # named parameter placeholder
            if names.has_key? named_param
              value = names[named_param] # named param already declared, so we can use the saved param name for it
            else
              idx = named_param[1..].to_i # use the index in the named param to find the related argument to bind to
              value = "@PARAM_CRYSTAL_TDS_#{named_param}__"
              parameters << "#{value} #{arguments[idx - 1].type_info.type}"
              names[named_param] = value                # save the named param in case its reused later in the query
              reordered_arguments << arguments[idx - 1] # argument values need to be reordered to match declaration order
            end
            named_params_found = true
          when value = scanner.scan(/./m) # all other tokens
          else
            raise DB::Error.new("Unexpected character encountered when parsing statement: #{scanner.peek(1).inspect}")
          end
          string << value
        end
      end

      raise DB::Error.new("Mixed use of parameter placeholders (?, $n) is not allowed: #{command}") if unnamed_params_found && named_params_found
      raise DB::Error.new("Too many arguments specified for statement: #{command}") if parameters.size < arguments.size

      reordered_arguments = arguments if unnamed_params_found

      {statement, parameters, reordered_arguments}
    rescue ex : ::IndexError
      raise DB::Error.new("Too few arguments specified for statement: #{command}", ex)
    end

    def conn
      @connection.as(Connection)
    end
  end
end
