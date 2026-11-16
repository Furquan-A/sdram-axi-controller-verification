class axi_read_sequence uvm_sequence #(axi_transaction);
	`uvm_object_utils(axi_read_sequence)
	
	function new(string name = "axi_read_sequence");
		super.new(name);
	endfunction 
	
	task body();
		
		axi_transaction tr = axi_transaction::type_id::create("tr");
		
		`uvm_info("AXI_RD_SEQ","starting READ sequence ",UVM_MEDIUM)
		
		start_item(tr);
		
		if(!tr.randomize() with {
			op == READ;
			addr == 32'h00000010;
			id == 4'd4;
			length == 0;
			burst == INCR;
		})
			`uvm_fatal("AXI_RD_SEQ","Randomization Failed")
		finish_item(tr);
	endtask 
endclass 