import uvm_pkg::*;
`include "uvm_macros.svh"

class sdram_responder extends uvm_component;

	`uvm_component_utils(sdram_responder)

	virtual sdram_if.RESPONDER vif;

	typedef logic [23:0] sdram_key_t;

	logic [15:0] memory[sdram_key_t];

	logic [12:0] open_row[4];
	bit row_valid[4];
	bit auto_precharge_pending[4];

	function new(string name = "sdram_responder", uvm_component parent = null);
		super.new(name,parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		if(!uvm_config_db#(virtual sdram_if.RESPONDER)::get(this,"","rsp_if",vif))
			`uvm_fatal("SDRAM_RSP","Cannot get the vif. Did you set it?")
	endfunction

	task run_phase(uvm_phase phase);

		logic [1:0] bank_index;
		logic [1:0] bank;
		logic [12:0] row;
		logic [8:0] column_addr;
		logic [8:0] column;
		logic [8:0] current_column;
		logic [8:0] current_read_column;

		sdram_key_t key;
		sdram_key_t read_key;

		logic [1:0] pending_bank;
		logic [12:0] pending_row;
		logic [8:0] pending_column;

		logic [15:0] write_data[0:1];
		logic [1:0] write_dqm[0:1];

		bit write_burst_active;
		int write_beat_count;
		bit sdram_dout_en;

		bit read_pending;
		int read_beat_count;
		int read_delay_count;
		int cas_latency;

		logic [1:0] pending_read_bank;
		logic [12:0] pending_read_row;
		logic [8:0] pending_read_column;

		logic [15:0] current_read_data;

		logic [2:0] burst_length_code;
		logic [2:0] cas_latency_code;
		int burst_length;
		bit burst_type;
		logic [1:0] op_mode_code;
		bit write_burst_mode;
		logic [2:0] reserved_bits;
		bit mode_reg_loaded;
		bit full_page_mode;
		logic [8:0] burst_mask;
		logic [8:0] read_burst_mask;
		bit read_data_cleanup_pending;

		super.run_phase(phase);

		// ---------------------------------------------------------
		// INITIALIZATION
		// ---------------------------------------------------------

		for(int i = 0; i < 4; i++)
			begin
				open_row[i] = '0;
				row_valid[i] = 0;
				auto_precharge_pending[i] = 0;
			end

		write_burst_active = 0;
		write_beat_count = 0;
		pending_bank = '0;
		pending_row = '0;
		pending_column = '0;
		read_pending = 0;
		read_beat_count = 0;
		read_delay_count = 0;
		pending_read_bank = '0;
		pending_read_row = '0;
		pending_read_column = '0;
		burst_type = 0;
		op_mode_code = 2'b00;
		write_burst_mode = 0;
		reserved_bits = 3'b000;
		mode_reg_loaded = 0;
		full_page_mode = 0;
		cas_latency = 0;
		burst_length = 0;
		burst_mask = '0;
		read_burst_mask = '0;
		vif.rsp_cb.sdram_data_input <= '0;
		read_data_cleanup_pending = 0;

		// ---------------------------------------------------------
		// MAIN RESPONDER LOOP
		// ---------------------------------------------------------

		forever
			begin

				@(vif.rsp_cb);
				
				if(read_data_cleanup_pending)
					begin
						vif.rsp_cb.sdram_data_input <= '0;
						read_data_cleanup_pending = 0;
					end

				// =========================================================
				// PENDING WRITE BURST BEAT
				// =========================================================

				if(write_burst_active)
					begin

						case(burst_length)
							1: burst_mask = 9'h000;
							2: burst_mask = 9'h001;
							4: burst_mask = 9'h003;
							8: burst_mask = 9'h007;
							512: burst_mask = 9'h1FF;
							default:
								begin
									burst_mask = 9'h000;
									`uvm_error("SDRAM_RSP",$sformatf("Unsupported WRITE burst length %0d",burst_length))
								end
						endcase

						if(burst_type == 1'b0)
							current_column = (pending_column & ~burst_mask) | ((pending_column + write_beat_count) & burst_mask);
						else
							current_column = (pending_column & ~burst_mask) | ((pending_column ^ write_beat_count) & burst_mask);

						write_data[1] = vif.rsp_cb.sdram_data_output;
						write_dqm[1] = vif.rsp_cb.sdram_dqm;
						sdram_dout_en = vif.rsp_cb.sdram_data_out_en;

						if(!sdram_dout_en)
							`uvm_error("SDRAM_RSP","SDRAM data output enable is 0 during WRITE burst")

						key = {pending_bank,pending_row,current_column};

						if(write_dqm[1] != 2'b11)
							begin
								if(!memory.exists(key))
									memory[key] = 16'h0000;

								if(!write_dqm[1][0])
									memory[key][7:0] = write_data[1][7:0];

								if(!write_dqm[1][1])
									memory[key][15:8] = write_data[1][15:8];
							end

						$display("WRITE BEAT[%0d] BANK=%0d ROW=0x%0h COL=0x%0h DATA=0x%0h DQM=%0b",write_beat_count,pending_bank,pending_row,current_column,write_data[1],write_dqm[1]);

						if(write_beat_count == burst_length - 1)
							begin
								write_beat_count = 0;
								write_burst_active = 0;

								if(auto_precharge_pending[pending_bank])
									begin
										row_valid[pending_bank] = 0;
										open_row[pending_bank] = '0;
										auto_precharge_pending[pending_bank] = 0;
										$display("AUTO PRECHARGE AFTER WRITE BANK=%0d",pending_bank);
									end
							end
						else
							write_beat_count++;

					end

				// =========================================================
				// PENDING SDRAM READ BURST
				// =========================================================

				if(read_pending)
					begin

						if(read_delay_count > 1)
							read_delay_count--;
						else
							begin

								if(read_delay_count == 1)
									read_delay_count = 0;

								case(burst_length)
									1: read_burst_mask = 9'h000;
									2: read_burst_mask = 9'h001;
									4: read_burst_mask = 9'h003;
									8: read_burst_mask = 9'h007;
									512: read_burst_mask = 9'h1FF;
									default:
										begin
											read_burst_mask = 9'h000;
											`uvm_error("SDRAM_RSP",$sformatf("Unsupported READ burst length %0d",burst_length))
										end
								endcase

								if(burst_type == 1'b0)
									current_read_column = (pending_read_column & ~read_burst_mask) | ((pending_read_column + read_beat_count) & read_burst_mask);
								else
									current_read_column = (pending_read_column & ~read_burst_mask) | ((pending_read_column ^ read_beat_count) & read_burst_mask);

								read_key = {pending_read_bank,pending_read_row,current_read_column};

								if(memory.exists(read_key))
									current_read_data = memory[read_key];
								else
									current_read_data = 16'h0000;

								vif.rsp_cb.sdram_data_input <= current_read_data;

								$display("READ BEAT[%0d] BANK=%0d ROW=0x%0h COL=0x%0h DATA=0x%0h",read_beat_count,pending_read_bank,pending_read_row,current_read_column,current_read_data);

								if(read_beat_count == burst_length - 1)
									begin
										read_beat_count = 0;
										read_pending = 0;
										
										read_data_cleanup_pending = 1;

										if(auto_precharge_pending[pending_read_bank])
											begin
												row_valid[pending_read_bank] = 0;
												open_row[pending_read_bank] = '0;
												auto_precharge_pending[pending_read_bank] = 0;
												$display("AUTO PRECHARGE AFTER READ BANK=%0d",pending_read_bank);
											end
									end
								else
									read_beat_count++;

							end

					end

				// =========================================================
				// ACTIVE COMMAND
				// CS#=0 RAS#=0 CAS#=1 WE#=1
				// =========================================================

				if(vif.rsp_cb.sdram_cas && vif.rsp_cb.sdram_we && !vif.rsp_cb.sdram_cs && !vif.rsp_cb.sdram_ras)
					begin
						bank_index = vif.rsp_cb.sdram_ba;
						open_row[bank_index] = vif.rsp_cb.sdram_addr;
						row_valid[bank_index] = 1;
						$display("ACTIVE BANK=%0d ROW=0x%0h",bank_index,vif.rsp_cb.sdram_addr);
					end

				// =========================================================
				// PRECHARGE COMMAND
				// CS#=0 RAS#=0 CAS#=1 WE#=0
				// =========================================================

				if(vif.rsp_cb.sdram_cas && !vif.rsp_cb.sdram_we && !vif.rsp_cb.sdram_cs && !vif.rsp_cb.sdram_ras)
					begin
						if(vif.rsp_cb.sdram_addr[10] == 1'b0)
							begin
								bank_index = vif.rsp_cb.sdram_ba;
								row_valid[bank_index] = 0;
								open_row[bank_index] = '0;
								auto_precharge_pending[bank_index] = 0;
								$display("PRECHARGE BANK=%0d",bank_index);
							end
						else
							begin
								for(int i = 0; i < 4; i++)
									begin
										open_row[i] = '0;
										row_valid[i] = 0;
										auto_precharge_pending[i] = 0;
									end
								$display("PRECHARGE ALL BANKS");
							end
					end
					
				// =========================================================
				// AUTO REFRESH COMMAND
				// CS#=0 RAS#=0 CAS#=0 WE#=1
				// =========================================================

				if(!vif.rsp_cb.sdram_cs  &&!vif.rsp_cb.sdram_ras && !vif.rsp_cb.sdram_cas &&vif.rsp_cb.sdram_we)
					begin

						for(int i = 0; i < 4; i++)
							begin

								if(row_valid[i])
									`uvm_error(
										"SDRAM_RSP",
										$sformatf(
											"AUTO REFRESH issued while Bank %0d still has an active row",
											i
										)
									)

							end

						$display("AUTO REFRESH COMMAND");

					end
					
				// =========================================================
				// BURST TERMINATE COMMAND
				// CS#=0 RAS#=1 CAS#=1 WE#=0
				// =========================================================

				if(!vif.rsp_cb.sdram_cs && vif.rsp_cb.sdram_ras && vif.rsp_cb.sdram_cas && !vif.rsp_cb.sdram_we)
					begin

						if(write_burst_active)
							begin
								write_burst_active = 0;
								write_beat_count = 0;
								$display("BURST TERMINATE: WRITE burst stopped");
							end

						if(read_pending)
							begin
								read_pending = 0;
								read_beat_count = 0;
								read_delay_count = 0;
								read_data_cleanup_pending = 1;

								$display("BURST TERMINATE: READ burst stopped");
							end

					end

				// =========================================================
				// SDRAM WRITE COMMAND
				// CS#=0 RAS#=1 CAS#=0 WE#=0
				// =========================================================

				if(!vif.rsp_cb.sdram_cas && !vif.rsp_cb.sdram_we && !vif.rsp_cb.sdram_cs && vif.rsp_cb.sdram_ras)
					begin
						if(!mode_reg_loaded)
							`uvm_error("SDRAM_RSP","WRITE command received before mode register was loaded")
							
						bank_index = vif.rsp_cb.sdram_ba;
						bank = bank_index;
						row = open_row[bank_index];
						column_addr = vif.rsp_cb.sdram_addr[8:0];
						column = column_addr;

						if(row_valid[bank_index])
							begin
								pending_bank = bank;
								pending_row = row;
								pending_column = column;
								key = {bank,row,column};

								write_data[0] = vif.rsp_cb.sdram_data_output;
								write_dqm[0] = vif.rsp_cb.sdram_dqm;
								sdram_dout_en = vif.rsp_cb.sdram_data_out_en;

								if(!sdram_dout_en)
									`uvm_error("SDRAM_RSP","SDRAM data output enable is 0 during first WRITE beat")

								if(write_dqm[0] != 2'b11)
									begin
										if(!memory.exists(key))
											memory[key] = 16'h0000;

										if(!write_dqm[0][0])
											memory[key][7:0] = write_data[0][7:0];

										if(!write_dqm[0][1])
											memory[key][15:8] = write_data[0][15:8];
									end

								if(vif.rsp_cb.sdram_addr[10])
									auto_precharge_pending[bank_index] = 1;

								$display("WRITE BEAT[0] BANK=%0d ROW=0x%0h COL=0x%0h DATA=0x%0h DQM=%0b ENABLE=%0b",bank,row,column,write_data[0],write_dqm[0],sdram_dout_en);

								if(write_burst_mode == 1'b1)
									begin
										write_beat_count = 0;
										write_burst_active = 0;

										if(auto_precharge_pending[bank])
											begin
												row_valid[bank] = 0;
												open_row[bank] = '0;
												auto_precharge_pending[bank] = 0;
												$display("AUTO PRECHARGE AFTER SINGLE WRITE BANK=%0d",bank);
											end
									end
								else if(burst_length > 1)
									begin
										write_beat_count = 1;
										write_burst_active = 1;
									end
								else
									begin
										write_beat_count = 0;
										write_burst_active = 0;

										if(auto_precharge_pending[bank])
											begin
												row_valid[bank] = 0;
												open_row[bank] = '0;
												auto_precharge_pending[bank] = 0;
												$display("AUTO PRECHARGE AFTER BL=1 WRITE BANK=%0d",bank);
											end
									end

							end
						else
							`uvm_error("SDRAM_RSP",$sformatf("WRITE issued to Bank %0d with no active row",bank_index))
					end

				// =========================================================
				// SDRAM READ COMMAND
				// CS#=0 RAS#=1 CAS#=0 WE#=1
				// =========================================================

				if(!vif.rsp_cb.sdram_cas && vif.rsp_cb.sdram_we && !vif.rsp_cb.sdram_cs && vif.rsp_cb.sdram_ras)
					begin
					
						if(!mode_reg_loaded)
							`uvm_error("SDRAM_RSP","READ command received before mode register was loaded")

						bank_index = vif.rsp_cb.sdram_ba;
						bank = bank_index;
						row = open_row[bank_index];
						column_addr = vif.rsp_cb.sdram_addr[8:0];
						column = column_addr;

						if(row_valid[bank_index])
							begin
								pending_read_bank = bank;
								pending_read_row = row;
								pending_read_column = column;
								read_delay_count = cas_latency;
								read_beat_count = 0;
								read_pending = 1;

								if(vif.rsp_cb.sdram_addr[10])
									auto_precharge_pending[bank_index] = 1;

								$display("READ COMMAND BANK=%0d ROW=0x%0h COL=0x%0h CAS_LATENCY=%0d",bank,row,column,cas_latency);
							end
						else
							`uvm_error("SDRAM_RSP",$sformatf("READ issued to Bank %0d with no active row",bank_index))
					end

				// =========================================================
				// LOAD MODE REGISTER
				// CS#=0 RAS#=0 CAS#=0 WE#=0
				// =========================================================

				if(!vif.rsp_cb.sdram_cs && !vif.rsp_cb.sdram_ras && !vif.rsp_cb.sdram_cas && !vif.rsp_cb.sdram_we)
					begin
						burst_length_code = vif.rsp_cb.sdram_addr[2:0];
						burst_type = vif.rsp_cb.sdram_addr[3];
						cas_latency_code = vif.rsp_cb.sdram_addr[6:4];
						op_mode_code = vif.rsp_cb.sdram_addr[8:7];
						write_burst_mode = vif.rsp_cb.sdram_addr[9];
						reserved_bits = vif.rsp_cb.sdram_addr[12:10];
						full_page_mode = 0;

						case(burst_length_code)
							3'b000: burst_length = 1;
							3'b001: burst_length = 2;
							3'b010: burst_length = 4;
							3'b011: burst_length = 8;
							3'b111:
								begin
									full_page_mode = 1;
									burst_length = 512;
								end
							default:
								begin
									burst_length = 0;
									`uvm_error("SDRAM_RSP",$sformatf("Reserved/unsupported burst length code %03b",burst_length_code))
								end
						endcase

						if(burst_type == 1'b0)
							$display("BURST TYPE = SEQUENTIAL");
						else
							$display("BURST TYPE = INTERLEAVED");

						case(cas_latency_code)
							3'b010: cas_latency = 2;
							3'b011: cas_latency = 3;
							default:
								begin
									cas_latency = 0;
									`uvm_error("SDRAM_RSP",$sformatf("Unsupported CAS latency code %03b",cas_latency_code))
								end
						endcase

						if(op_mode_code != 2'b00)
							`uvm_error("SDRAM_RSP",$sformatf("Reserved operating mode selected: %02b",op_mode_code))

						if(write_burst_mode)
							$display("WRITE BURST MODE = SINGLE LOCATION");
						else
							$display("WRITE BURST MODE = PROGRAMMED BURST LENGTH");

						if(reserved_bits != 3'b000)
							`uvm_error("SDRAM_RSP",$sformatf("Reserved mode register bits [12:10] are not zero: %03b",reserved_bits))

						mode_reg_loaded = 1;

						$display("--------------------------------------------------");
						$display("SDRAM MODE REGISTER LOADED");
						$display("BL CODE          = %03b",burst_length_code);
						$display("BURST LENGTH     = %0d",burst_length);
						$display("BURST TYPE       = %s",burst_type ? "INTERLEAVED" : "SEQUENTIAL");
						$display("CAS LATENCY      = %0d",cas_latency);
						$display("OPERATING MODE   = %02b",op_mode_code);
						$display("WRITE BURST MODE = %s",write_burst_mode ? "SINGLE LOCATION" : "PROGRAMMED BURST LENGTH");
						$display("RESERVED         = %03b",reserved_bits);
						$display("--------------------------------------------------");
					end

			end

	endtask

endclass