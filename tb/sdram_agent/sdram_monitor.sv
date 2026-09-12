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
		logic [8:0] column_addr;
		logic [13:0] row;
		logic [1:0] bank;
		logic [15:0] write_data[0:1];
		logic [1:0] write_dqm[1:2];
		bit write_burst_active; // Indicates that an SDRAM BL=2 write burst is currently in progress.
		bit write_beat_count; // Tracks which 16-bit SDRAM write beat is being captured: 0 = first beat, 1 = second beat. 
		bit sdram_dout_en;
		
		row_valid[0] = 0;
		row_valid[1] = 0;
		row_valid[2] = 0;
		row_valid[3] = 0;
		write_burst_active = 0;
		write_beat_count = 0;
		
		forever 
			begin
				@(vif.mon_cb);
				
				if (write_burst_active && write_beat_count) 
				begin
					write_data[1] = vif.mon_cb.sdram_data_output;
					write_dqm[1]  = vif.mon_cb.sdram_dqm;
					sdram_dout_en = vif.mon_cb.sdram_data_out_en;

					if (!sdram_dout_en)
						`uvm_error("SDRAM_MON", "SDRAM data output enable is 0 during second WRITE beat")

					$display("WRITE BEAT[1] DATA=0x%0h DQM=%0b ENABLE=%0b", write_data[1], write_dqm[1], sdram_dout_en);

					write_beat_count   = 0;
					write_burst_active = 0;
				end
				
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
								auto_precharge_pending[bank_index] = 0;
								
								$display("PRECHARGE BANK=%0d", bank_index);
							end
						else 
							begin 	// A10 = 1 → PRECHARGE ALL banks
								for(int i = 0; i < 4 ; i++)
									begin 
										open_row[i] = '0;
										row_valid[i] = 0;
										auto_precharge_pending[i] = 0;
									end
							end 
					end 
					
				if(!vif.mon_cb.sdram_cas && vif.mon_cb.sdram_we && !vif.mon_cb.sdram_cs && vif.mon_cb.sdram_ras)
					begin
						// READ Command 
						// Select bank and column, and start read burst 
						// bank has already been selected by the active command 
						//open_row[bank_index] = vif.mon_cb.sdram_addr; // column addr for read 
						bank_index  = vif.mon_cb.sdram_ba;
						column_addr = vif.mon_cb.sdram_addr[8:0];
						
						if(row_valid[bank_index]== 1)
							begin 
								//reconstruct
								bank = bank_index;
								row  = open_row[bank_index];
								column = column_addr;
								$display("READ BANK=%0d ROW=0x%0h COLUMN=0x%0h",bank_index,open_row[bank_index],column_addr);
								if (vif.mon_cb.sdram_addr[10] == 1'b1)
									auto_precharge_pending[bank_index] = 1;
							end 
						else 
							`uvm_error("SDRAM_MON",$sformatf("READ issued to Bank %0d with no active row",bank_index))
					end 
					
				if(!vif.mon_cb.sdram_cas && !vif.mon_cb.sdram_we && !vif.mon_cb.sdram_cs && vif.mon_cb.sdram_ras)
					begin 
						// Write COMMAND
						bank_index = vif.mon_cb.sdram_ba;
						column_addr = vif.mon_cb.sdram_addr[8:0];
						
						if(row_valid[bank_index]==1)
							begin 
								bank = bank_index;
								row  = open_row[bank_index];
								column = column_addr;
								$display("WRITE BANK=%0d ROW=0x%0h COLUMN=0x%0h",bank_index,open_row[bank_index],column_addr);
								
								// Capture Beat 1 
								write_data[0] = vif.mon_cb.sdram_data_output;
								write_dqm[0] = vif.mon_cb.sdram_dqm;
								sdram_dout_en = vif.mon_cb.sdram_data_out_en;
								if (sdram_dout_en == 0)
									`uvm_error("SDRAM_MON","SDRAM data output enable is 0 during WRITE")
								
								$display("sdram_d_output = 0x%0h  dqm = 0x%0b enable = %0b",write_data[0],write_dqm[0],sdram_dout_en);
								
								// Check for the Auto Precharge
								if(vif.mon_cb.sdram_addr[10] == 1) 
										auto_precharge_pending[bank_index] = 1;

								write_beat_count = 1;
								write_burst_active = 1;
									
							end 
						else 
							`uvm_error("SDRAM_MON",$sformatf("WRITE ISSUED to the bank %0d with no active row",bank_index))
					end 
					
				if(write_beat_count && write_burst_active) 
					begin 
						// with the writcapturing is still in progress , capture the second beat 
						write_data[1] = vif.mon_cb.sdram_data_output;
						write_dqm[1] = vif.mon_cb.sdram_dqm;
						sdram_dout_en = vif.mon_cb.sdram_data_out_en;
						if (sdram_dout_en == 0)
							`uvm_error("SDRAM_MON","SDRAM data output enable is 0 during WRITE")
						
						write_beat_count = 0;
						write_burst_active = 0;
					end 
					
	endtask