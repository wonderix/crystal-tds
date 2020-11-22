require "./utf16_io.cr"
require "./errno.cr"

module TDS::Trace
  {% if flag?(:trace) %}
    INDENT = Atomic.new(0)
  {% end %}

  macro trace(value)
    {% if flag?(:trace) %}
    ::puts " #{ " " * TDS::Trace::INDENT.get}{{value}} = #{ ({{value}}).inspect }"
    {% end %}
  end

  macro trace_push
    {% if flag?(:trace) %}
    TDS::Trace::INDENT.add(2)
    {% end %}
  end

  macro trace_pop
    {% if flag?(:trace) %}
    TDS::Trace::INDENT.sub(2)
    {% end %}
  end
end
