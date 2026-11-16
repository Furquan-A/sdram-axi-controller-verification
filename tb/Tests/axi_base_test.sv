class axi_base_test extends uvm_test;
	`uvm_component_utils(axi_base_test)
	
	//virtual axi_if vif;
	axi_sdram_env envh;
	
	function new(string name = "axi_base_test",uvm_component parent=null);
		super.new(name,parent);
	endfunction 
	
	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		
		envh = axi_sdram_env::type_id::create("envh",this,);
	endfunction
	
	task run_phase(uvm_phase phase);
		axi_write_sequence write_seq;
		phase.raise_objection(this);
		write_seq = axi_write_sequence::type_id::create("write_seq");
		write_seq.start(envh.axi_agent.seqr);
		phase.drop_objection(this);
		
	endtask 
endclass