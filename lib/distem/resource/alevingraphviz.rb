require 'graphviz'
# GraphViz monkeypatch to parse alevin DOT files

class  GraphViz
  module Constants
    NODESATTRS.merge!({"cpu" => :EscString,"type" => :EscString, "ip" =>:EscString,"bandwidth" => :EscString, "kind" => :EscString})
    EDGESATTRS.merge!({"bandwidth" => :EscString, "key" => :EscString})
  end
end
