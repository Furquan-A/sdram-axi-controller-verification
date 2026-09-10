class sdram_monitor extends uvm_monitor;
	`uvm_component_utils(sdram_monitor)
	
	virtual sdram_if.MONITOR vif;
	//uvm_analysis_fifo#(sdram_transaction) ap;
	logic [12:0] open_row[4];
	bit          row_valid[4];
	
	function new(string name = "sdram_monitor", uvm_component parent);
		super.new(name,parent);
		//ap = new("ap");
	endfunction 
	
	
	
	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		
		if(!uvm_config_db#(virtual sdram_if.MONITOR)::get(this,"","sdram_vif",vif))
			`uvm_fatal("SDRAM_MON","Cannot get SDRAM interface from config_db. Was it set?")
		
	endfunction 
	
	task run_phase(uvm_phase phase);
		super.run_phase(phase);
		
		logic [1:0] bank_index;
		
		row_valid[0] = 0;
		row_valid[1] = 0;
		row_valid[2] = 0;
		row_valid[3] = 0;
		
		forever 
			begin
				@(vif.mon_cb);
				if(vif.mon_cb.sdram_cas && vif.mon_cb.sdram_we && !vif.mon_cb.sdram_cs && !vif.mon_cb.sdram_ras)
					begin 
						// ACTIVE COMMAND
						// select the bank and activate the row 
						bank_index = vif.mon_cb.sdram_ba;
						open_row[bank_index] = vif.mon_cb.sdram_addr;
						row_valid[bank_index] = 1;
						$display("ACTIVE BANK=%2d ROW=0x0h",bank_index,open_row[bank_index]);
					end 
				
				if(vif.mon_cb.sdram_cas && !vif.mon_cb.sdram_we && !vif.mon_cb.sdram_cs && !vif.mon_cb.sdram_ras)
					begin 	
						// PRECHARGE COMMAND 
						// A10 = 0 → PRECHARGE selected bank
						 if (vif.mon_cb.sdram_addr[10] == 1'b0)
							begin
								bank_index = vif.mon_cb.sdram_ba;
								row_valid[bank_index] = 0;
								open_row[bank_index]  = '0;
							end
						else 
							begin 	
								for(int i = 0; i < 4 ; i++)
									begin 
										open_row[i] = '0;
										row_valid[i] = 0;
									end
							end 
	endtask