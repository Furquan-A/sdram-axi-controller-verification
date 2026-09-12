import uvm_pkg::*;
`include "uvm_macros.svh"

class sdram_monitor extends uvm_monitor;

	`uvm_component_utils(sdram_monitor)
	
	virtual sdram_if.MONITOR vif;

	//uvm_analysis_fifo#(sdram_transaction) ap;

	logic [12:0] open_row[4];
	bit          row_valid[4];
	bit          auto_precharge_pending[4];
	
	function new(string name = "sdram_monitor", uvm_component parent = null);
		super.new(name,parent);
		//ap = new("ap");
	endfunction 
	
	
	
	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		
		if(!uvm_config_db#(virtual sdram_if.MONITOR)::get(this,"","sdram_vif",vif))
			`uvm_fatal("SDRAM_MON","Cannot get SDRAM interface from config_db. Was it set?")
		
	endfunction 
	
	
	task run_phase(uvm_phase phase);
		
		logic [1:0]  bank_index;
		logic [8:0]  column_addr;
		logic [8:0]  column;
		logic [12:0] row;
		logic [1:0]  bank;

		logic [15:0] write_data[0:1];
		logic [1:0]  write_dqm[0:1];

		bit write_burst_active; // Indicates that an SDRAM BL=2 write burst is currently in progress.
		bit write_beat_count;   // Tracks which 16-bit SDRAM write beat is being captured: 0 = first beat, 1 = second beat.
		bit sdram_dout_en;

		logic [12:0] mode_reg;

		logic [2:0] burst_length_code;
		int         burst_length;

		bit         burst_type;

		logic [2:0] cas_latency_code;
		int         cas_latency;

		logic [1:0] op_mode_code;
		bit         op_mode;

		bit         write_burst_mode_code;

		logic [2:0] reserved_bits;
		
		
		super.run_phase(phase);
		
		
		row_valid[0] = 0;
		row_valid[1] = 0;
		row_valid[2] = 0;
		row_valid[3] = 0;

		open_row[0] = '0;
		open_row[1] = '0;
		open_row[2] = '0;
		open_row[3] = '0;

		auto_precharge_pending[0] = 0;
		auto_precharge_pending[1] = 0;
		auto_precharge_pending[2] = 0;
		auto_precharge_pending[3] = 0;

		write_burst_active = 0;
		write_beat_count   = 0;
		
		
		forever 
			begin

				@(vif.mon_cb);
				
				
				// =====================================================
				// CAPTURE SECOND BEAT OF PREVIOUS BL=2 WRITE
				// =====================================================
				
				if(write_burst_active && write_beat_count) 
					begin

						write_data[1] = vif.mon_cb.sdram_data_output;
						write_dqm[1]  = vif.mon_cb.sdram_dqm;
						sdram_dout_en = vif.mon_cb.sdram_data_out_en;

						if(!sdram_dout_en)
							`uvm_error("SDRAM_MON","SDRAM data output enable is 0 during second WRITE beat")

						$display("WRITE BEAT[1] DATA=0x%0h DQM=%0b ENABLE=%0b",write_data[1],write_dqm[1],sdram_dout_en);

						write_beat_count   = 0;
						write_burst_active = 0;

					end
				
				
				// =====================================================
				// ACTIVE COMMAND
				// CS# = 0, RAS# = 0, CAS# = 1, WE# = 1
				// =====================================================
				
				if(vif.mon_cb.sdram_cas && vif.mon_cb.sdram_we && !vif.mon_cb.sdram_cs && !vif.mon_cb.sdram_ras)
					begin 

						// ACTIVE COMMAND
						// Select the bank and activate the row

						bank_index = vif.mon_cb.sdram_ba;

						open_row[bank_index]  = vif.mon_cb.sdram_addr;
						row_valid[bank_index] = 1;

						$display("ACTIVE BANK=%0d ROW=0x%0h",bank_index,open_row[bank_index]);

					end 
				
				
				// =====================================================
				// PRECHARGE COMMAND
				// CS# = 0, RAS# = 0, CAS# = 1, WE# = 0
				// =====================================================
				
				if(vif.mon_cb.sdram_cas && !vif.mon_cb.sdram_we && !vif.mon_cb.sdram_cs && !vif.mon_cb.sdram_ras)
					begin 	

						// PRECHARGE COMMAND
						// A10 = 0 -> PRECHARGE selected bank

						if(vif.mon_cb.sdram_addr[10] == 1'b0)
							begin

								bank_index = vif.mon_cb.sdram_ba;

								row_valid[bank_index]               = 0;
								open_row[bank_index]                = '0;
								auto_precharge_pending[bank_index] = 0;
								
								$display("PRECHARGE BANK=%0d",bank_index);

							end

						else 
							begin 	

								// A10 = 1 -> PRECHARGE ALL banks

								for(int i = 0; i < 4; i++)
									begin 

										open_row[i]                = '0;
										row_valid[i]                = 0;
										auto_precharge_pending[i] = 0;

									end

								$display("PRECHARGE ALL BANKS");

							end 

					end 
				
				
				// =====================================================
				// READ COMMAND
				// CS# = 0, RAS# = 1, CAS# = 0, WE# = 1
				// =====================================================
				
				if(!vif.mon_cb.sdram_cas && vif.mon_cb.sdram_we && !vif.mon_cb.sdram_cs && vif.mon_cb.sdram_ras)
					begin

						// READ COMMAND
						// Select bank and column and start read burst

						bank_index  = vif.mon_cb.sdram_ba;
						column_addr = vif.mon_cb.sdram_addr[8:0];
						
						if(row_valid[bank_index] == 1)
							begin 

								// Reconstruct complete SDRAM location

								bank   = bank_index;
								row    = open_row[bank_index];
								column = column_addr;

								$display("READ BANK=%0d ROW=0x%0h COLUMN=0x%0h",bank, row, column);

								// A10 = 1 -> READ with auto-precharge

								if(vif.mon_cb.sdram_addr[10] == 1'b1)
									auto_precharge_pending[bank_index] = 1;

							end 

						else 
							`uvm_error("SDRAM_MON",$sformatf("READ issued to Bank %0d with no active row",bank_index))

					end 
				
				
				// =====================================================
				// WRITE COMMAND
				// CS# = 0, RAS# = 1, CAS# = 0, WE# = 0
				// =====================================================
				
				if(!vif.mon_cb.sdram_cas && !vif.mon_cb.sdram_we && !vif.mon_cb.sdram_cs && vif.mon_cb.sdram_ras)
					begin 

						// WRITE COMMAND

						bank_index  = vif.mon_cb.sdram_ba;
						column_addr = vif.mon_cb.sdram_addr[8:0];
						
						if(row_valid[bank_index] == 1)
							begin 

								bank   = bank_index;
								row    = open_row[bank_index];
								column = column_addr;

								$display("WRITE BANK=%0d ROW=0x%0h COLUMN=0x%0h",bank,row,column);
								
								// Capture first 16-bit SDRAM beat

								write_data[0] = vif.mon_cb.sdram_data_output;
								write_dqm[0]  = vif.mon_cb.sdram_dqm;
								sdram_dout_en = vif.mon_cb.sdram_data_out_en;

								if(sdram_dout_en == 0)
									`uvm_error("SDRAM_MON","SDRAM data output enable is 0 during first WRITE beat")
								
								$display("WRITE BEAT[0] DATA=0x%0h DQM=%0b ENABLE=%0b",write_data[0],write_dqm[0],sdram_dout_en);
								
								// Check for auto-precharge

								if(vif.mon_cb.sdram_addr[10] == 1'b1) 
									auto_precharge_pending[bank_index] = 1;

								// Tell the monitor that the next clock contains beat 2

								write_beat_count   = 1;
								write_burst_active = 1;
									
							end 

						else 
							`uvm_error("SDRAM_MON",$sformatf("WRITE issued to Bank %0d with no active row",bank_index))

					end 
				
				
				// =====================================================
				// AUTO REFRESH / SELF REFRESH
				// CS# = 0, RAS# = 0, CAS# = 0, WE# = 1
				// =====================================================
				
				if(!vif.mon_cb.sdram_cas && vif.mon_cb.sdram_we && !vif.mon_cb.sdram_cs && !vif.mon_cb.sdram_ras)
					begin 

						// REFRESH / SELF-REFRESH

						if(vif.mon_cb.sdram_cke)
							$display("AUTO REFRESH detected");
						else 
							$display("SELF REFRESH detected");

					end 
				
				
				// =====================================================
				// LOAD MODE REGISTER
				// CS# = 0, RAS# = 0, CAS# = 0, WE# = 0
				// =====================================================
				
				if(!vif.mon_cb.sdram_cas && !vif.mon_cb.sdram_we && !vif.mon_cb.sdram_cs && !vif.mon_cb.sdram_ras)
					begin

						// LOAD MODE REGISTER
						// Capture all 13 bits so reserved bits can also be checked

						mode_reg = vif.mon_cb.sdram_addr;

						$display("MODE REGISTER value is %0b",mode_reg);
						
						
						// -------------------------------------------------
						// BURST LENGTH
						// mode_reg[2:0]
						// -------------------------------------------------

						burst_length_code = mode_reg[2:0];
						
						case(burst_length_code)

							3'b000: 
								begin
									burst_length = 1;
									$display("SDRAM BURST LENGTH = %0d",burst_length);
								end

							3'b001: 
								begin
									burst_length = 2;
									$display("SDRAM BURST LENGTH = %0d",burst_length);
								end

							3'b010: 
								begin
									burst_length = 4;
									$display("SDRAM BURST LENGTH = %0d",burst_length);
								end

							3'b011: 
								begin
									burst_length = 8;
									$display("SDRAM BURST LENGTH = %0d",burst_length);
								end

							3'b111: 
								begin

									burst_length = -1;
									$display("SDRAM BURST LENGTH = FULL PAGE");

								end

							default: 
								begin

									burst_length = 0;
									`uvm_error("SDRAM_MON",$sformatf("Illegal/unsupported SDRAM burst length encoding: %03b",burst_length_code))

								end

						endcase
						
						
						// -------------------------------------------------
						// BURST TYPE
						// mode_reg[3]
						// -------------------------------------------------

						burst_type = mode_reg[3];
						
						if(burst_type == 1'b1)
							$display("Interleaved burst type");
						else
							$display("Sequential burst type");
						
						
						// -------------------------------------------------
						// CAS LATENCY
						// mode_reg[6:4]
						// -------------------------------------------------

						cas_latency_code = mode_reg[6:4];
						
						case(cas_latency_code)
						
							3'b010: 
								begin

									cas_latency = 2;
									$display("SDRAM CAS LATENCY = %0d",cas_latency);

								end

							3'b011: 
								begin

									cas_latency = 3;
									$display("SDRAM CAS LATENCY = %0d",cas_latency);

								end

							default: 
								begin

									cas_latency = 0;
									$display("SDRAM CAS LATENCY encoding %03b is reserved/unsupported",cas_latency_code);

								end

						endcase
						
						
						// -------------------------------------------------
						// OPERATING MODE
						// mode_reg[8:7]
						// -------------------------------------------------

						op_mode_code = mode_reg[8:7];

						case(op_mode_code)
						
							2'b00: 
								begin 

									op_mode = 1;
									$display("NORMAL operating mode");

								end 

							default: 
								begin 

									op_mode = 0;
									$display("Reserved/unsupported operating mode");

								end

						endcase
						
						
						// -------------------------------------------------
						// WRITE BURST MODE
						// mode_reg[9]
						// -------------------------------------------------

						write_burst_mode_code = mode_reg[9];

						if(write_burst_mode_code == 1'b0)
							$display("Programmed burst length");
						else 
							$display("Single location access");
						
						
						// -------------------------------------------------
						// RESERVED BITS
						// mode_reg[12:10]
						// -------------------------------------------------

						reserved_bits = mode_reg[12:10];

						if(reserved_bits == 3'b000)
							$display("The DUT has programmed the reserved bits correctly");
						else 
							`uvm_error("SDRAM_MON",$sformatf("Reserved bits %03b are not valid",reserved_bits))

					end
				
				
				// =====================================================
				// BURST TERMINATE COMMAND
				// CS# = 0, RAS# = 1, CAS# = 1, WE# = 0
				// =====================================================
				
				if(vif.mon_cb.sdram_cas && !vif.mon_cb.sdram_we && !vif.mon_cb.sdram_cs && vif.mon_cb.sdram_ras)
					begin 

						$display("BURST TERMINATE IS DETECTED");

					end 
			
			end
	
	endtask

endclass