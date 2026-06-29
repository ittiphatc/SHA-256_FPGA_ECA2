`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    01/07/2026
// Design Name: 
// Module Name:    sha256_top 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module sha256_top (
    input  wire        clk,
    input  wire        rst_n,
    
    // Streaming Input Interface
    input  wire        write_en,    // สั่งเขียนข้อมูล 1 Word
    input  wire [31:0] data_in,     // ท่อรับข้อมูลทีละ 32 บิต
    //input  wire [1:0]  byte_valid,  // จำนวนไบต์จริงใน Word สุดท้าย (0=4, 1=1, 2=2, 3=3 bytes)
    input  wire [31:0]   data_size,
    input  wire        load_done,   // สัญญาณบอกว่าส่งข้อมูลเสร็จแล้ว
    
    // Streaming Output Interface
    input  wire [2:0]  read_addr,   // เลือกอ่านค่า Hash (0-7 สำหรับ Hash_a ถึง Hash_h)
    output wire [31:0] hash_out,    // ท่อส่งข้อมูล Hash ออกทีละ 32 บิต
    output reg         sha_done     // สัญญาณบอกว่าคำนวณเสร็จแล้ว พร้อมให้อ่านค่า
);

    // ==========================================
    // 1. FSM State Definitions
    // ==========================================
    localparam [2:0] 
        IDLE = 3'd0,
        LOAD = 3'd1,
        PAD  = 3'd2,
        CALC = 3'd3,
        DONE = 3'd4;

    reg [2:0] current_state, next_state;
    reg [1:0] saved_byte_valid;
    
    // ==========================================
    // 2. Internal Registers & Variables
    // ==========================================
    reg [5:0]  counter;      
    reg [3:0]  word_count;   
    reg [31:0] W [0:15];     
    reg [31:0] message_length; 
    
    reg [31:0] a_i, b_i, c_i, d_i, e_i, f_i, g_i, h_i;
    reg [31:0] k;
    
    // Register สำหรับเก็บค่า Hash ตอนคำนวณเสร็จ (เพื่อให้ภายนอกเลือกอ่าน)
    reg [31:0] hash_reg [0:7];
    
    wire [31:0] a_o, b_o, c_o, d_o, e_o, f_o, g_o, h_o;
    wire [31:0] s0, s1, w_new;
    
    integer i;

    // ==========================================
    // 3. Output Multiplexer (Streaming Out)
    // ==========================================
    // ส่งค่าแฮชออกไปที่ hash_out ตามตำแหน่ง read_addr ที่ระบบภายนอกระบุมา
    assign hash_out = hash_reg[read_addr];

    // ==========================================
    // 4. W Expansion Logic (Combinational)
    // ==========================================
    wire [31:0] w1_val  = W[1];
    wire [31:0] w14_val = W[14];
    
    assign s0 = {w1_val[6:0], w1_val[31:7]} ^ {w1_val[17:0], w1_val[31:18]} ^ {3'b000, w1_val[31:3]};
    assign s1 = {w14_val[16:0], w14_val[31:17]} ^ {w14_val[18:0], w14_val[31:19]} ^ {10'b0000000000, w14_val[31:10]};
    assign w_new = W[0] + s0 + W[9] + s1;

    // ==========================================
    // 5. K Constant Lookup Table
    // ==========================================
    always @(*) begin
        case(counter)
            6'd0:  k = 32'h428a2f98; 6'd1:  k = 32'h71374491; 6'd2:  k = 32'hb5c0fbcf; 6'd3:  k = 32'he9b5dba5;
            6'd4:  k = 32'h3956c25b; 6'd5:  k = 32'h59f111f1; 6'd6:  k = 32'h923f82a4; 6'd7:  k = 32'hab1c5ed5;
            6'd8:  k = 32'hd807aa98; 6'd9:  k = 32'h12835b01; 6'd10: k = 32'h243185be; 6'd11: k = 32'h550c7dc3;
            6'd12: k = 32'h72be5d74; 6'd13: k = 32'h80deb1fe; 6'd14: k = 32'h9bdc06a7; 6'd15: k = 32'hc19bf174;
            6'd16: k = 32'he49b69c1; 6'd17: k = 32'hefbe4786; 6'd18: k = 32'h0fc19dc6; 6'd19: k = 32'h240ca1cc;
            6'd20: k = 32'h2de92c6f; 6'd21: k = 32'h4a7484aa; 6'd22: k = 32'h5cb0a9dc; 6'd23: k = 32'h76f988da;
            6'd24: k = 32'h983e5152; 6'd25: k = 32'ha831c66d; 6'd26: k = 32'hb00327c8; 6'd27: k = 32'hbf597fc7;
            6'd28: k = 32'hc6e00bf3; 6'd29: k = 32'hd5a79147; 6'd30: k = 32'h06ca6351; 6'd31: k = 32'h14292967;
            6'd32: k = 32'h27b70a85; 6'd33: k = 32'h2e1b2138; 6'd34: k = 32'h4d2c6dfc; 6'd35: k = 32'h53380d13;
            6'd36: k = 32'h650a7354; 6'd37: k = 32'h766a0abb; 6'd38: k = 32'h81c2c92e; 6'd39: k = 32'h92722c85;
            6'd40: k = 32'ha2bfe8a1; 6'd41: k = 32'ha81a664b; 6'd42: k = 32'hc24b8b70; 6'd43: k = 32'hc76c51a3;
            6'd44: k = 32'hd192e819; 6'd45: k = 32'hd6990624; 6'd46: k = 32'hf40e3585; 6'd47: k = 32'h106aa070;
            6'd48: k = 32'h19a4c116; 6'd49: k = 32'h1e376c08; 6'd50: k = 32'h2748774c; 6'd51: k = 32'h34b0bcb5;
            6'd52: k = 32'h391c0cb3; 6'd53: k = 32'h4ed8aa4a; 6'd54: k = 32'h5b9cca4f; 6'd55: k = 32'h682e6ff3;
            6'd56: k = 32'h748f82ee; 6'd57: k = 32'h78a5636f; 6'd58: k = 32'h84c87814; 6'd59: k = 32'h8cc70208;
            6'd60: k = 32'h90befffa; 6'd61: k = 32'ha4506ceb; 6'd62: k = 32'hbef9a3f7; 6'd63: k = 32'hc67178f2;
            default: k = 32'h00000000;
        endcase
    end


    // ==========================================================
    // 🚀 FSM & Data Path (แบบ Single Block รวดเดียวจบ ไร้บั๊ก State ค้าง)
    // ==========================================================
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            current_state    <= IDLE;
            word_count       <= 0;
            message_length   <= 0;
            counter          <= 0;
            sha_done         <= 0;
            saved_byte_valid <= 0;
            
            for (i = 0; i < 16; i = i + 1) W[i] <= 32'h0;
            
            a_i <= 32'h6a09e667; b_i <= 32'hbb67ae85; c_i <= 32'h3c6ef372; d_i <= 32'ha54ff53a;
            e_i <= 32'h510e527f; f_i <= 32'h9b05688c; g_i <= 32'h1f83d9ab; h_i <= 32'h5be0cd19;
        end 
        else begin
            case (current_state)
                IDLE: begin
                    word_count     <= 0;
                    message_length <= 0;
                    counter        <= 0;
                    if (write_en) sha_done <= 0;
                    
                    a_i <= 32'h6a09e667; b_i <= 32'hbb67ae85; c_i <= 32'h3c6ef372; d_i <= 32'ha54ff53a;
                    e_i <= 32'h510e527f; f_i <= 32'h9b05688c; g_i <= 32'h1f83d9ab; h_i <= 32'h5be0cd19;

                    if (write_en) begin
                        W[0]             <= data_in;
                        word_count       <= 1;
                        message_length   <= 32;
                        saved_byte_valid <= data_size[1:0];
                        current_state    <= LOAD; // 🎯 ดูดคำแรกปุ๊บ สั่งย้ายสเตตทันที
                    end
                end

                LOAD: begin
                    if (load_done) begin
                        current_state <= PAD; // 🎯 จบสตรีม สั่งย้ายไปทำ Padding
                    end 
                    else if (write_en) begin
                        W[word_count]    <= data_in;
                        word_count       <= word_count + 1;
                        message_length   <= message_length + 32;
                        saved_byte_valid <= data_size[1:0];
                    end
                end

                PAD: begin
                    current_state <= CALC; // 🎯 แปะบิตเสร็จ บังคับย้ายไปคำนวณรอบถัดไปเลย!

                    // 1. แปะ 0x80
                    case (saved_byte_valid)
                        2'd1: W[word_count - 1] <= {W[word_count - 1][31:24], 8'h80, 16'h0000};
                        2'd2: W[word_count - 1] <= {W[word_count - 1][31:16], 8'h80, 8'h00};
                        2'd3: W[word_count - 1] <= {W[word_count - 1][31:8], 8'h80};
                        default: W[word_count]  <= 32'h80000000;
                    endcase

                    // 2. ถมศูนย์เฉพาะ W[1] ถึง W[14] 
                    for (i = 0; i < 14; i = i + 1) begin
                        if (saved_byte_valid != 2'd0 && i >= word_count) begin
                            W[i] <= 32'h00000000;
                        end
                        else if (saved_byte_valid == 2'd0 && i > word_count) begin
                            W[i] <= 32'h00000000;
                        end
                    end
                    W[14] <= 32'h00000000;

                    // 3. ยัดความยาวบิตลงช่องสุดท้าย W[15]
                    if (saved_byte_valid == 2'd1)      W[15] <= message_length - 24;
                    else if (saved_byte_valid == 2'd2) W[15] <= message_length - 16;
                    else if (saved_byte_valid == 2'd3) W[15] <= message_length - 8;
                    else                               W[15] <= message_length;
                end

                CALC: begin
                    counter <= counter + 1; // 🎯 เริ่มนับลูป 0 ถึง 63
                    
                    if (counter == 63) begin
                        current_state <= DONE; // 🎯 คำนวณครบ 64 รอบปุ๊บ ย้ายไปสเตตปิดจ๊อบ
                    end

                    // ลูปสไลด์ท่อหมุนข้อมูลส่งเข้าคอร์
                    for (i = 0; i < 15; i = i + 1) begin
                        W[i] <= W[i+1];
                    end
                    W[15] <= w_new;

                    // รับค่ารอบปัจจุบันไปเป็นตั้งต้นของรอบถัดไป
                    a_i <= a_o; b_i <= b_o; c_i <= c_o; d_i <= d_o;
                    e_i <= e_o; f_i <= f_o; g_i <= g_o; h_i <= h_o;
                end

                DONE: begin
                    sha_done <= 1; // 🎯 ประกาศชัยชนะ!
                    
                    // บวกทบค่ากลับเข้า Hash Register
                    hash_reg[0] <= a_i + 32'h6a09e667;
                    hash_reg[1] <= b_i + 32'hbb67ae85;
                    hash_reg[2] <= c_i + 32'h3c6ef372;
                    hash_reg[3] <= d_i + 32'ha54ff53a;
                    hash_reg[4] <= e_i + 32'h510e527f;
                    hash_reg[5] <= f_i + 32'h9b05688c;
                    hash_reg[6] <= g_i + 32'h1f83d9ab;
                    hash_reg[7] <= h_i + 32'h5be0cd19;
                    
                    current_state <= IDLE; // 🎯 วนกลับไปรอรับข้อมูลคำใหม่
                end
            endcase
        end
    end

    // ==========================================
    // 8. Core Instantiation
    // ==========================================
    sha256_core sha256_core_inst (
        .a_i (a_i), .b_i (b_i), .c_i (c_i), .d_i (d_i),
        .e_i (e_i), .f_i (f_i), .g_i (g_i), .h_i (h_i),
        .a_o (a_o), .b_o (b_o), .c_o (c_o), .d_o (d_o),
        .e_o (e_o), .f_o (f_o), .g_o (g_o), .h_o (h_o),
        .w   (W[0]),
        .k   (k)
    );

endmodule

