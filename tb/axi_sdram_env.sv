class axi_sdram_env extends uvm_env;
	`uvm_component_utils(axi_sdram_env)
	
	axi_agent axi_agnth;
	sdram_agent sdram_agnth;
	
	function new(sting name = "axi_sdram_env",ucm_component parent = null);
		super.new(name,parent);
	endfunction 
	
	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		
		axi_agnth = axi_agent::type_id::create("axi_agnth",this);
		sdram_agnth = sdram_agent::type_id::create("sdram_agnth",this);
	endfunction 
enclass 