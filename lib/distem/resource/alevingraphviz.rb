require 'graphviz'
# GraphViz monkeypatch to parse alevin DOT files

class  GraphViz
  module Constants
    NODESATTRS.merge!({"cpu" => :EscString,"type" => :EscString, "ip" =>:EscString })
    EDGESATTRS.merge!({"bandwidth" => :EscString})
  end
end
