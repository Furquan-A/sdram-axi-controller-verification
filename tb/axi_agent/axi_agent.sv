class axi_agent extends uvm_agent;
	`uvm_component_utils(axi_agent)
	
	virtual axi_if vif;
	axi_driver drvh;
	axi_monitor monh;
	axi_sequencer seqrh;
	axi_agent_config cfg;
	
	function new(string name ="axi_agent",uvm_component parent = null);
		super.new(name,parent);
	endfunction 
	
	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		
		if(!uvm_config_db #(virtual axi_if)::get(this,"","vif",vif))
			`uvm_fatal("AXI_AGENT","Cannot get the vif. Did you set it?")
		
		monh = axi_monitor::type_id::create("monh",this);
		if(cfg.is_active)
			begin 
				drvh = axi_driver::type_id::create("drvh",this);
				seqrh = axi_sequencer::type_id::create("seqrh",this);
			end 
			
		cfg.vif = vif;
	endfunction 
	
	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		if(cfg.is_active)
			drvh.seq_item_port.connect(seqrh.seq_item_export);
	endfunction 
endclass 

		
	