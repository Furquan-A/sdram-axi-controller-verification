import uvm_pkg::*;
`include "uvm_macros.svh"

class axi_transaction extends uvm_sequence_item;
	`uvm_object_util(axi_transaction) // override Capability is one of the major reason UVM uses Factory 
	
	parameter int AXI_ADDR_WIDTH = 32;
	parameter int AXI_DATA_WIDTH = 32;
	parameter int ID_WIDTH   = 4;
	parameter int LEN_WIDTH  = 8;
	
	function new(string name = "axi_transaction");
		super.name(name);
	endfunction 
	
	typedef enum logic [1:0] {
		FIXED = 2'b00,
		INCR  = 2'b01,
		WRAP  = 2'b10
	} burst_type_e;
	typedef enum logic [1:0] {
		OKAY = 2'b00,
		EXOKAY = 2'b01,
		SLVERR = 2'b10,
		DECERR = 2'b11
	}resp_type_e;
	
	typedef enum logic {
		READ  = 1'b0,
		WRITE = 1'b1
	} op_e;
		
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
	
	
	
	// constraints 
	constraint burst_size_c {
		w_data.size() == length+1;
		wstrb.size()  == length+1;
	}
	
	constraint fixed_burst_length_c {
		if (burst == FIXED)
			length inside {[0:15]};
	}

	constraint incr_burst_length_c {
		if (burst == INCR)
			length inside {[0:255]};
	}

	constraint wrap_burst_length_c {
		if (burst == WRAP)
			length inside {1, 3, 7, 15};
	}
	
	constraint array_size_c {
		if (op == WRITE) {
			w_data.size() == length + 1;
			wstrb.size()  == length + 1;
		}
		else {
			w_data.size() == 0;
			wstrb.size()  == 0;
		}
	}
	
	constraint address_range_c {
		addr inside {[32'h0000_0000 : 32'h01FF_FFFF]}; // 0 - 33,554,431 -- 4K mem
	}
	
	constraint address_aligned_c {
		addr[1:0] == 2'b00;
	}
	
	constraint address_4k_boundary_c {
		if (burst == INCR)
			addr[11:0] +
			((length + 1) * (AXI_DATA_WIDTH/8))
			<= 4096;
	}
	
	constraint wrap_burst_c {
		if (burst == WRAP)
			length inside {1,3,7,15}; // inside [2,4,8,16]
	}
	
	constraint incr_burst_address_c {
		if(burst == INCR)
			(addr + ((AXI_DATA_WIDTH/8)*(length+1))-1) <= 32'h01FF_FFFF;
	}
	
	
	
endclass
	