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

    # Replaces `?` placeholders with `@P$n__` where n = 0..n placeholders in
    # the given SQL statement, returning the updated statement, and array of
    # parameter names and types for `sp_prepare` or `sp_executesql`
    def parameterize(command : String, arguments : Array(Parameter)) : {String, Array(String), Array(Parameter)}
      index, names, parameters, reordered_arguments = 0, Hash(String, String).new, Array(String).new, Array(Parameter).new(arguments.size)
      unnamed_params_found, named_params_found = false, false

      statement = String.build(command.size) do |string|
        scanner = StringScanner.new(command.lstrip(" \t").rstrip)
        until scanner.eos?
          case
          when value = scanner.scan(/\[([^\]]|\]\])*\]/m) # bracket quoted value, including escaped right brackets such as `]]`
            # treat as a literal and do not modify
          when value = scanner.scan(/'([^']|'')*'/m) # single quoted value, including escaped single-quotes such as `''`
            # treat as a literal and do not modify
          when value = scanner.scan(/"([^"]|"")*"/m) # double quoted value, including escaped double-quotes such as `""`
            # treat as a literal and do not modify
          when value = scanner.scan(/--.*/) # single line comment
            # minify statement by removing comments
            value = ""
          when comment_start = scanner.scan(/\/\*/) # multi-line comment
            unless scanner.scan(/.*?\*\//m)
              scanner.terminate
            end
            # minify statement by removing comments
            value = ""
          when unnamed_param = scanner.scan('?') # unnamed parameter placeholder
            index += 1
            value = "@P$#{index}__"
            parameters << value
            unnamed_params_found = true
          when named_param = scanner.scan(/\$\d+/) # named parameter placeholder
            if names.has_key? named_param
              # named param already declared, so we can use the saved param name for it
              value = names[named_param]
            else
              # use the index in the named param to find the related argument to bind to
              idx = named_param[1..].to_i
              value = "@P#{named_param}__"
              parameters << value
              # save the named param in case its reused later in the query
              names[named_param] = value
              # argument values need to be reordered to match declaration order
              reordered_arguments << arguments[idx - 1]
            end
            named_params_found = true
          when value = scanner.scan(/\s+/) # one or more whitespace characters
            # when value includes a newline or carriage return, normalize to
            # newlines and preserve all newlines to ensure line numbers
            # continue to match original statement for diagnostics but remove
            # all spaces and tabs, otherwise replace runs of spaces and tabs
            # with a single space character
            if value.includes?("\n") || value.includes?("\r")
              # remove all spaces and tabs, replace CRLF with LF, and CR with LF
              value = value.gsub(/[ \t]/, "").gsub("\r\n", "\n").gsub("\r", "\n")
            else
              # replace runs of spaces and tabs with a single space character
              value = " "
            end
          when value = scanner.scan(/./m) # all other tokens
            # treat as a literal and do not modify
          else
            raise DB::Error.new("Unexpected character encountered when parsing: #{scanner.peek(1).inspect} -- query = #{command.inspect}, args = #{arguments.map { |a| a.value }.inspect}")
          end
          string << value
        end
      end

      raise DB::Error.new("Incorrect use of parameter placeholders: using both ? and $n style placeholders within single query not allowed, choose one placeholder style and use only that style within each query -- query = #{command.inspect}, args = #{arguments.map { |a| a.value }.inspect}") if unnamed_params_found && named_params_found
      raise DB::Error.new("Incorrect number of arguments: expected #{parameters.size}, but received #{arguments.size} -- query = #{command.inspect}, args = #{arguments.map { |a| a.value }.inspect}") if parameters.size != arguments.size

      {statement, parameters.map_with_index { |value, i| "#{value} #{arguments[i].type_info.type}" }, unnamed_params_found ? arguments : reordered_arguments}
    end

    def conn
      @connection.as(Connection)
    end
  end
end
