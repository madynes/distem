require 'distem'

pnode = ARGV[1]
algo = ARGV[2]


Distem.client do |cl|
  cl.pnode_update(pnode, {"algorithms"=>{"cpu"=>algo}})
end
