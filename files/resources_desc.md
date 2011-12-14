# Resources description
Distem resources description
## Instructions
In this file <small>[r/w]</small>, specify if a resource is _readable_ and/or _writable_ when accessing it throught the Network API (REST).

Hashes are described with ruby structure.

If a resource name is specified between [] that mean that its a table of this resource type. Sample: [<a href="#pnode_core">__cores__</a>].

## <a name="pnode">Physical Node</a>
<tt>Type:</tt> **Hash**

<tt>Structure overview:</tt>

* __id__ <small>[r]</small>: The unique id of this physical machine.
* __address__ <small>[r]</small>: The ip address of the physical node.
* <a href="#pnode_status">__status__</a> <small>[r]</small>: The current status of this resource.
* <a href="#pnode_algos">__algorithms__</a>: The algorithm that are currently in use to apply the different limitation on physical resources.
    * cpu
* <a href="#pnode_memory">__memory__</a>: The description of the physical memory of this machine.
    * capacity
    * swap
* <a href="#pnode_cpu">__cpu__</a>: The descriptio of the CPU of this machine.
    * id
    * [<a href="#pnode_core">cores</a>]
        * physicalid
        * coreid
        * frequency
        * frequencies
        * cache_links
    * [cores_alloc]
    * [critical_cache_links]
* <strike>__max_vifaces__:  The maximum number of virtual network interfaces that shoud be created on this physical node.</strike>


<tt>Sample:</tt>

    {
      "address"=>"172.16.65.80",
      "memory"=>{"capacity"=>"16086 Mo", "swap"=>"3820 Mo"},
      "id"=>"0",
      "algorithms"=>{"cpu"=>"hogs"},
      "cpu"=>
       {"cores"=>
         [{"physicalid"=>"5",
           "frequencies"=>["2000 MHz", "2500 MHz"],
           "coreid"=>"6",
           "frequency"=>"2500 MHz",
           "cache_links"=>["7"]},
          {"physicalid"=>"0",
           "frequencies"=>["2000 MHz", "2500 MHz"],
           "coreid"=>"0",
           "frequency"=>"2500 MHz",
           "cache_links"=>["2"]},
          {"physicalid"=>"6",
           "frequencies"=>["2000 MHz", "2500 MHz"],
           "coreid"=>"3",
           "frequency"=>"2500 MHz",
           "cache_links"=>["4"]},
          ...
        ],
        "cores_alloc"=>
         [{"vnode"=>"node2", "core"=>"5"},
          {"vnode"=>"node2", "core"=>"0"},
          {"vnode"=>"node2", "core"=>"6"}],
        "id"=>"69972201354320",
        "critical_cache_links"=>[["0", "2"], ["4", "6"], ["1", "3"], ["5", "7"]]},
      "status"=>"RUNNING"
    }

---

### <a name="pnode_status">Status</a>
<tt>Availability:</tt> **Read** / **Write**

<tt>Type:</tt> **String**

<tt>Values:</tt>

* __CONFIGURING__ <small>[r]</small>: The machine is currently being configured
* __RUNNING__ <small>[r/w]</small>: The physical machine is running

---

### <a name="pnode_algos">Algoritms</a>
<tt>Type:</tt> **Hash**

<tt>Structure overview:</tt>

* __cpu__ <small>[r/w]</small>: The algorithm to be used for CPU emulation (limitations). Values: _Hogs_, _Gov_.

<tt>Sample:</tt>

    {
      "cpu"=>"hogs"
    }

---

### <a name="pnode_memory">Memory</a>

<tt>Type:</tt> **Hash**

<tt>Structure overview:</tt>

* __capacity__ <small>[r]</small>: The amount of physical memory this machine is owning.
* __swap__ <small>[r]</small>: The amount of swap memory this machine is owning.

<tt>Sample:</tt>

    {
      "capacity"=>"16086 Mo",
      "swap"=>"3820 Mo"
    }

---

### <a name="pnode_cpu">CPU</a>
<tt>Type:</tt> **Hash**

<tt>Structure overview:</tt>

* __id__ <small>[r]</small>: The unique id of this physical CPU.
* __cores_alloc__ <small>[r]</small>: Array of Hashes. Hashes are describing the association between a virtual node -_vnode_- and a physical core -_core_-.
    * vnode
    * core
* __critical_cache_links__ <small>[r]</small>: Array of Arrays. On some CPUs a core cannot change his frequency independently from other cores. Each Array is describing the link between cores (i.e. the ones that should change their frequencies together). Core are specified by _physicalid_.
* [<a href="#pnode_core">__cores__</a>]: The cores of this CPU.
    * physicalid
    * coreid
    * frequency
    * frequencies
    * cache_links

<tt>Sample:</tt>

    {
      "id"=>"69972201354320",
      "cores"=>[
        {
          "physicalid"=>"5",
          "frequencies"=>["2000 MHz", "2500 MHz"],
          "coreid"=>"6",
          "frequency"=>"2500 MHz",
          "cache_links"=>["7"]
        },
        {
          "physicalid"=>"0",
          "frequencies"=>["2000 MHz", "2500 MHz"],
          "coreid"=>"0",
          "frequency"=>"2500 MHz",
          "cache_links"=>["2"]
        },
        {
          "physicalid"=>"6",
          "frequencies"=>["2000 MHz", "2500 MHz"],
          "coreid"=>"3",
          "frequency"=>"2500 MHz",
          "cache_links"=>["4"]
        },
        ...
      ],
      "cores_alloc"=>[
        {"vnode"=>"node2", "core"=>"5"},
        {"vnode"=>"node2", "core"=>"0"},
        {"vnode"=>"node2", "core"=>"6"}
      ],
      "critical_cache_links"=>[
        ["0", "2"],
        ["4", "6"],
        ["1", "3"],
        ["5", "7"]
      ]
    }

---

### <a name="pnode_core">Core</a>
<tt>Type:</tt> **Hash**

<tt>Structure overview:</tt>

* __physicalid__ <small>[r]</small>: The physical id of this core as specified by hwloc
* __coreid__ <small>[r]</small>: The core id of this core as specified by hwloc
* __frequency__ <small>[r]</small>: The current frequency this core is set to work on
* __frequencies__ <small>[r]</small>: The available frequencies this core is able to use
* __cache_links__ <small>[r]</small>: On some CPUs a core cannot change his frequency independently from other cores. This Array is describing the link between this core and other ones (i.e. the ones that should change their frequencies with this core). Core are specified by _physicalid_.

<tt>Sample:</tt>

    {
      "physicalid"=>"5",
      "frequencies"=>["2000 MHz", "2500 MHz"],
      "coreid"=>"6",
      "frequency"=>"2500 MHz",
      "cache_links"=>["7"]
    }

---

## <a name="vnode">Virtual Node</a>
<tt>Type:</tt> **Hash**

<tt>Structure overview:</tt>

* __host__ <small>[r/w]</small>: The address of the physical node the virtual node should be created on.
* __gateway__ <small>[r/w]</small>: Gateway or normal mode. Values: _true_,_false_.
* <a href="#vnode_sshkey">__ssh_key__</a>: The SSH key pair to be used on this virtual node
* <a href="#vnode_status">__status__</a> <small>[r/w]</small>: The current status of this virtual node
* <a href="#vnode_cpu">__vcpu__</a>: The virtual CPU of this virtual node
    * [<a href="#vnode_core">vcores</a>]
        * pcore
        * frequency
    * pcpu
* <a href="#vnode_filesystem">__vfilesystem__</a>: The virtual filesystem of this virtual node
    * shared
    * path
    * sharedpath
    * image
* [<a href="#vnode_iface">__vifaces__</a>]: The different virtual network interfaces of this virtual node
    * name
    * vnetwork
    * address
    * <a href="#vnode_traffic">input</a>
        * bandwidth
        * latency
    * <a href="#vnode_traffic">output</a>
        * bandwidth
        * latency

<tt>Sample:</tt>

    {
      "name"=>"node1",
      "status"=>"RUNNING",
      "gateway"=>false,
      "host"=>"192.168.0.1",
      "vfilesystem"=>{
        "sharedpath"=>nil,
        "shared"=>false,
        "path"=>"/tmp/distem/rootfs-unique/node1",
        "image"=>"file:///home/lsarzyniec/rootfs.tar.gz"
      },
      "ssh_key"=>{"public"=>"ssh-rsa AAAs4f5G...sD3gFf", "private"=>"M1HdH32F...sOA4s"},
      "vifaces"=>[
        {
          "name"=>"if0",
          "address"=>"10.144.2.1/24",
          "vnetwork"=>"network1",
          "output"=>{
            "bandwidth"=>{"rate" => "100mbps"},
            "latency"=>{"delay" => "2ms"}
          },
          "input"=>{
            "bandwidth"=>{"rate" => "20mbps"},
            "latency"=>{"delay" => "5ms"}
          }
        }
      ],
      "vcpu"=>{
        "vcores"=>[
          {"id"=>"0", "pcore"=>"5", "frequency"=>"1000 MHz"},
          {"id"=>"1", "pcore"=>"0", "frequency"=>"1000 MHz"},
          {"id"=>"2", "pcore"=>"6", "frequency"=>"1000 MHz"},
          {"id"=>"3", "pcore"=>"1", "frequency"=>"1000 MHz"}
        ],
        "pcpu"=>"69972201094900"
      }
    }


---

### <a name="vnode_status">Status</a>
<tt>Availability:</tt> **Read** / **Write**

<tt>Type:</tt> **String**

<tt>Values:</tt>

* __INIT__ <small>[r]</small>: This virtual node is currently being described and was never started
* __CONFIGURING__ <small>[r]</small>: This virtual node is currently being configured
* __READY__ <small>[r/w]</small>: The virtual node is ready to be runned but not running.
* __RUNNING__ <small>[r/w]</small>: The virtual node is running.

When starting a virtual node (going from state _READY_ to _RUNNING_), a physical node (that have enought physical resources (CPU,...)) will be automatically allocated if there is none set as _host_ at the moment. A filesystem image must have been set. The filesystem will be copied on the host physical node.

When stopping a virtual node (going from state _RUNNING_ to _READY_), deleting its data from the hosting physical node. The _host_ association for this virtual node will be cancelled, if you start the virtual node directcly after stopping it, the hosting physical node will be chosen randomly (to set it manually, see _host_ field in <a href="#vnode">VNode description</a>).

---

### <a name="vnode_sshkey">SSH Key Pair</a>
<tt>Availability:</tt> **Read** / **Write**

<tt>Type:</tt> **Hash**

<tt>Description:</tt> SSH key pair to be copied on the virtual node (also adding the public key to .ssh/authorized_keys). Note that every SSH keys located on the physical node which hosts this virtual node are also copied in .ssh/ directory of the node (copied key have a specific filename prefix). The key are copied in .ssh/ directory of SSH user (see _Distem::Daemon::Admin::SSH_USER_ and _Distem::Node::Container::SSH_KEY_FILENAME_). Both of _public_ and _private_ parameters are optional

<tt>Structure overview:</tt>

* __public__ <small>[r/w]</small>: String that describes the ssh public key that should be used by the virtual node (with the _ssh-rsa_ or _ssh-dsa_ prefix).
* __private__ <small>[r/w]</small>: String that describes the ssh private key that should be used by the virtual node.

<tt>Sample:</tt>
    {
      "public"=>"ssh-rsa AAAs4f5G...sD3gFf",
      "private"=>"M1HdH32F...sOA4s"
    }

---

### <a name="vnode_cpu">CPU</a>
<tt>Type:</tt> **Hash**

<tt>Structure overview:</tt>

* [<a href="#vnode_core">__cores__</a>]: The virtual cores of this virtual cpu
    * pcore
    * frequency
* __pcpu__ <small>[r]</small>: The physical CPU associated to this virtual one

This parameters are also taken in account:

* __corenb__ The number of cores to allocate (need to have enough free ones on the physical node)
* __frequency__ The frequency each node have to be set (need to be lesser or equal than the physical core frequency). If the frequency is included in ]0,1] itll be interpreted as a percentage of the physical core frequency, otherwise the frequency will be set to the specified number

<tt>Sample:</tt>
    {
      "vcores"=>[
        {"id"=>"0", "pcore"=>"5", "frequency"=>"1000 MHz"},
        {"id"=>"1", "pcore"=>"0", "frequency"=>"1000 MHz"},
        {"id"=>"2", "pcore"=>"6", "frequency"=>"1000 MHz"},
        {"id"=>"3", "pcore"=>"1", "frequency"=>"1000 MHz"}
      ],
      "pcpu"=>"69972201094900"
    }

---

#### <a name="vnode_core">Core</a>
<tt>Type:</tt> **Hash**

<tt>Structure overview:</tt>

* __pcore__ <small>[r]</small>: the physical core (physicalid) associated to this virtual resource.
* __frequency__ <small>[r]</small>: The frequency each node have to be set (need to be lesser or equal than the physical core frequency). If the frequency is included in ]0,1] itll be interpreted as a percentage of the physical core frequency, otherwise the frequency will be set to the specified number

<tt>Sample:</tt>
    {
      "pcore"=>"1",
      "frequency"=>"1000 MHz"
    }

---

### <a name="vnode_filesystem">File System</a>
<tt>Type:</tt> **Hash**

<tt>Structure overview:</tt>

* __image__ <small>[r/w]</small>: The URI to a compressed archive that should contain the virtual node file system.
* __shared__ <small>[r/w]</small>: Share the file system of this virtual node with every other virtual node that have this property (local to the physical node). Values: _true_,_false_.
* __path__ <small>[r]</small>: The path to the unique directory used to store this virtual node files
* __sharedpath__ <small>[r]</small>: The path to the shared directory used to store this virtual node shared files

<tt>Sample:</tt>

    {
      "sharedpath"=>"/tmp/distem/rootfs-shared/rootfs.tar.gz-1315906532-...",
      "shared"=>true,
      "path"=>"/tmp/distem/rootfs-unique/nodegw",
      "image"=>"file:///home/lsarzyniec/rootfs.tar.gz"
    }

---

### <a name="vnode_iface">Network interface</a>
<tt>Type:</tt> **Hash**

<tt>Structure overview:</tt>

* __name__ <small>[r]</small>: The name of this virtual network interface
* __vnetwork__ <small>[r/w]</small>: The virtual network (_name_) this virtual interface is connected to
* __address__ <small>[r/w]</small>: The ip address of this virtual network interface
* <a href="#vnode_traffic">__input__</a>: The description of the input traffic
    * bandwidth
    * latency
* <a href="#vnode_traffic">__output__</a>: The description of the output traffic
    * bandwidth
    * latency

<tt>Sample</tt>:
    {
      "name"=>"if0",
      "address"=>"10.144.2.1/24",
      "vnetwork"=>"network1",
      "output"=>{
        "bandwidth"=>{"rate" => "100mbps"},
        "latency"=>{"delay" => "2ms"}
      },
      "input"=>{
        "bandwidth"=>{"rate" => "20mbps"},
        "latency"=>{"delay" => "5ms"}
      }
    }

---

#### <a name="vnode_traffic">Traffic</a>
<tt>Type:</tt> **Hash**

<tt>Structure overview:</tt>

* __bandwidth__ <small>[r/w]</small>: The bandwidth description
    * __rate__ <small>[r/w]</small>: The speed of the connection (linux/tc units, see _man tc_)
* __latency__ <small>[r/w]</small>: The latency description
    * __delay__ <small>[r/w]</small>: The delay of the connection (linux/tc units, see _man tc_)

<tt>Sample</tt>:
    {
      "bandwidth"=>{"rate" => "20mbps"},
      "latency"=>{"delay" => "5ms"}
    }
