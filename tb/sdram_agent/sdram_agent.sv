class sdram_agent extends uvm_agent;
	`uvm_component_utils(sdram_agent)
	
	sdram_monitor monh;
	sdram_responder resp;
	
	virtual sdram_if vif;
	
	function new(string name = "sdram_agent", uvm_component parent = null);
		super.new(name,parent)
	endfunction 
	
	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		
		monh = sdram_monitor::type_id::create("monh",this);
		resp = sdram_responder::type_id::create("resp",this);
		
	endfunction 
	
endclass 
