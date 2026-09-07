import uvm_pkg::*;
`include "uvm_macros.svh"

class axi_transaction extends uvm_sequence_item;
	`uvm_object_util(axi_transaction) // override Capability is one of the major reason UVM uses Factory 
	
	parameter int AXI_ADDR_WIDTH = 32;
	parameter int AXI_DATA_WIDTH = 32;
	parameter int ID_WIDTH   = 4;
	parameter int LEN_WIDTH  = ;
	
	function new(string name = "axi_transaction");
		super.name(name);
	endfunction 
	
	typedef enum logic [1:0] burst_type{FIXED,INCR,WRAP}burst_type_e;
	typedef enum logic [1:0] resp_type{OKAY,EXOKAY,SLVERR,DECERR}resp_type_e;
	typedef enum {READ,WRITE}op_e;
	
	rand logic [AXI_ADDR_WIDTH-1:0] addr;
	rand logic [AXI_DATA_WIDTH-1:0] w_data[];
	rand logic [(AXI_DATA_WIDTH/8)-1:0] wstrb[];
	rand logic [ID_WIDTH-1:0] id;
	rand logic [LEN_WIDTH-1:0] length;

	rand burst_type_e burst;
	rand op_e         op;

	// DUT-generated results
	logic [AXI_DATA_WIDTH-1:0] r_data[];
	resp_type_e                bresp; // One resp for one complete Transaction
	resp_type_e                rresp[]; // each beat needs one rresp 
	
	
	
	
	
endclass
