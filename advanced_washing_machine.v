`timescale 1ns / 1ps

module advanced_washing_machine (
    input clk,
    input reset,
    input start,
    input door_closed,
    input [1:0] mode,             // 00: Quick, 01: Normal, 10: Heavy, 11: Delicate
    input water_level_reached,    // Sensor input: 1 when water is full
    
    output reg water_valve,       // Opens valve to fill water
    output reg motor_wash,        // Tumbles the drum slowly
    output reg drain_valve,       // Opens valve to drain water
    output reg motor_spin,        // Spins drum fast for drying
    output reg door_lock,         // Engages door lock
    output reg done_led,          // Signals completion
    output reg fault_alarm        // Signals an error (e.g., door open)
);

    // --- State Encoding (Simplified) ---
    localparam IDLE       = 3'b000,
               FILL_WATER = 3'b001,
               WASH       = 3'b010,
               DRAIN      = 3'b011,
               SPIN       = 3'b100,
               DONE       = 3'b101,
               FAULT      = 3'b110;

    reg [2:0] current_state, next_state;

    // --- Timer Variables ---
    reg [7:0] timer;
    reg [7:0] wash_time;
    reg [7:0] spin_time;
    reg timer_en;
    reg timer_reset;

    // --- Mode Configurations ---
    always @(*) begin
        case (mode)
            2'b00: begin wash_time = 8'd20; spin_time = 8'd10; end // Quick
            2'b01: begin wash_time = 8'd40; spin_time = 8'd20; end // Normal
            2'b10: begin wash_time = 8'd60; spin_time = 8'd30; end // Heavy
            2'b11: begin wash_time = 8'd30; spin_time = 8'd10; end // Delicate
            default: begin wash_time = 8'd40; spin_time = 8'd20; end
        endcase
    end

    // --- Timer Logic (The Stopwatch) ---
    always @(posedge clk or posedge reset) begin
        if (reset || timer_reset) begin
            timer <= 8'd0;
        end else if (timer_en) begin
            timer <= timer + 1;
        end
    end

    // --- State Transition (The Memory) ---
    always @(posedge clk or posedge reset) begin
        if (reset)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    // --- Next State and Output Logic (The Brain) ---
    always @(*) begin
        // 1. Turn everything off by default
        next_state = current_state;
        water_valve = 0;
        motor_wash = 0;
        drain_valve = 0;
        motor_spin = 0;
        door_lock = 0;
        done_led = 0;
        fault_alarm = 0;
        timer_en = 0;
        timer_reset = 0;

        // 2. Safety check: Did the door pop open?
        if (!door_closed && current_state != IDLE && current_state != DONE && current_state != FAULT) begin
            next_state = FAULT;
        end else begin
            
            // 3. The Checklist (FSM)
            case (current_state)
                IDLE: begin
                    timer_reset = 1;
                    if (start && door_closed) begin
                        door_lock = 1;
                        next_state = FILL_WATER;
                    end
                end

                FILL_WATER: begin
                    door_lock = 1;
                    water_valve = 1;
                    if (water_level_reached) begin
                        next_state = WASH; // Goes straight to wash now!
                        timer_reset = 1;
                    end
                end

                WASH: begin
                    door_lock = 1;
                    motor_wash = 1;
                    timer_en = 1;
                    if (timer >= wash_time) begin
                        next_state = DRAIN;
                        timer_reset = 1;
                    end
                end

                DRAIN: begin
                    door_lock = 1;
                    drain_valve = 1;
                    timer_en = 1;
                    if (timer >= 8'd10) begin // Draining takes 10 clock ticks
                        next_state = SPIN;
                        timer_reset = 1;
                    end
                end

                SPIN: begin
                    door_lock = 1;
                    drain_valve = 1;
                    motor_spin = 1;
                    timer_en = 1;
                    if (timer >= spin_time) begin
                        next_state = DONE;
                        timer_reset = 1;
                    end
                end

                DONE: begin
                    done_led = 1;
                    door_lock = 0; // Safe to open door
                    if (!start) begin // Wait for user to flip the start switch back off
                        next_state = IDLE;
                    end
                end

                FAULT: begin
                    fault_alarm = 1;
                    drain_valve = 1;
                    door_lock = 0;
                    if (reset) begin
                        next_state = IDLE;
                    end
                end

                default: next_state = IDLE;
            endcase
        end
    end

endmodule