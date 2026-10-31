import uvm_pkg::*;
`include "uvm_macros.svh"

class sdram_rsp_test extends uvm_test;

	`uvm_component_utils(sdram_rsp_test)

	sdram_responder rsp;
	virtual sdram_if vif;


	function new(string name = "sdram_rsp_test", uvm_component parent = null);
		super.new(name,parent);
	endfunction


	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		if(!uvm_config_db#(virtual sdram_if)::get(this,"","sdram_vif",vif))
			`uvm_fatal("RSP_TEST","Cannot get the interface. Did you set it?")

		rsp = sdram_responder::type_id::create("rsp",this);

	endfunction


	task run_phase(uvm_phase phase);

		phase.raise_objection(this);

		// Stimulus will go here later

		phase.drop_objection(this);

	endtask

endclass