class axi_write_sequence extends uvm_sequence #(axi_transaction);
	`uvm_object_utils(axi_write_sequence)
	
	function new(string name = "axi_write_sequence");
		super.new(name);
	endfunction 
	
	task body();
	
		axi_transaction tr;
		tr = axi_transaction::type_id::create("tr");
		
		`uvm_info("AXI_WR_SEQ","Starting write sequence",UVM_MEDIUM)
		start_item(tr);
		
		if(!tr.randomize() with {
			op == WRITE;
			addr == 32'h00000010;
			id == 4'd4;
			length == 0;
			burst == INCR;
			wstrb[0] == 4'b1111;
		})
			`uvm_fatal("AXI_WR_SEQ","Transaction randomization failed")
		
		finish_item(tr);
	endtask
endclass