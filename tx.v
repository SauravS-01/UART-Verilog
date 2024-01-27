module uart_tx #(parameter CLKS_PER_BIT)
  (
   input       i_Clock,
   input       tx_data_valid,
   input [7:0] in, 
   output      tx_active,
   output reg  tx_serial_data,
   output      tx_done
   );

  // Define state values for the state machine
  parameter idle        = 3'b000;
  parameter start_bit    = 3'b001;
  parameter data_bit     = 3'b010;
  parameter stop_bit     = 3'b011;
  parameter cleanup      = 3'b100;

  // Registers to hold various state and control information
  reg [2:0]    tx_state     = 0;
  reg [7:0]    t_clock_count = 0;
  reg [2:0]    t_bit_index   = 0;
  reg [7:0]    data          = 0;
  reg          int_done      = 0;
  reg          int_active    = 0;

  // Always block triggered on the positive edge of the clock
  always @(posedge i_Clock)
    begin
      // State machine implementation
      case (tx_state)
        // IDLE state
        idle :
          begin
            tx_serial_data   <= 1'b1;   // Drive Line High for Idle
            int_done     <= 1'b0;
            t_clock_count <= 0;
            t_bit_index   <= 0;

            // Check if there is valid data to transmit
            if (tx_data_valid == 1'b1)
              begin
                int_active <= 1'b1;    // Set transmitter as active
                data   <= in;          // Store data to be transmitted
                tx_state   <= start_bit;  // Move to the start_bit state
              end
            else
              tx_state <= idle;  // Stay in the idle state
          end // case: idle

        // START BIT state
        start_bit :
          begin
            tx_serial_data <= 1'b0;  // Transmit Start bit (logic 0)

            // Wait for CLKS_PER_BIT-1 clock cycles for start bit to finish
            if (t_clock_count < CLKS_PER_BIT-1)
              begin
                t_clock_count <= t_clock_count + 1;
                tx_state     <= start_bit;
              end
            else
              begin
                t_clock_count <= 0;
                tx_state     <= data_bit;  // Move to the data_bit state
              end
          end // case: start_bit

        // DATA BIT state
        data_bit :
          begin
            tx_serial_data <= data[t_bit_index];  // Transmit data bit

            // Wait for CLKS_PER_BIT-1 clock cycles for data bit to finish
            if (t_clock_count < CLKS_PER_BIT-1)
              begin
                t_clock_count <= t_clock_count + 1;
                tx_state     <= data_bit;
              end
            else
              begin
                t_clock_count <= 0;

                // Check if we have sent out all bits
                if (t_bit_index < 7)
                  begin
                    t_bit_index <= t_bit_index + 1;
                    tx_state   <= data_bit;
                  end
                else
                  begin
                    t_bit_index <= 0;
                    tx_state   <= stop_bit;  // Move to the stop_bit state
                  end
              end
          end // case: data_bit

        // STOP BIT state
        stop_bit :
          begin
            tx_serial_data <= 1'b1;  // Transmit Stop bit (logic 1)

            // Wait for CLKS_PER_BIT-1 clock cycles for stop bit to finish
            if (t_clock_count < CLKS_PER_BIT-1)
              begin
                t_clock_count <= t_clock_count + 1;
                tx_state     <= stop_bit;
              end
            else
              begin
                int_done     <= 1'b1;  // Set transmission as done
                t_clock_count <= 0;
                tx_state     <= cleanup;  // Move to the cleanup state
                int_active   <= 1'b0;  // Clear transmitter active flag
              end
          end // case: stop_bit

        // CLEANUP state
        cleanup :
          begin
            int_done <= 1'b1;  // Set transmission as done
            tx_state <= idle;  // Move back to the idle state
          end

        default :
          tx_state <= idle;  // Default state is idle
      endcase
    end

  // Assign the transmitter active and done signals to external ports
  assign tx_active = int_active;
  assign tx_done   = int_done;

endmodule
