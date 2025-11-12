 //`define DEBUG

// ================================================================
// ============ ABS FUNC =========================================
// ================================================================
function real abs_func(input real x);
    return (x < 0) ? -x : x;
endfunction



// ================================================================
// ============ ABSTRACT BASE CLASS ===============================
// ================================================================
class Shape_c;
    string name;
    real points[$][2];

    function new(string name, real points[$][2]);
        this.name   = name;
        this.points = points;
    endfunction

    // Pure virtual
    virtual function real get_area();
    endfunction

    function void print();
        $display("--------------------------------------------------------------------------------");
        $display("This is: %s", name);
        foreach (points[i]) begin
            $display(" (%0.2f, %0.2f)", points[i][0], points[i][1]);
        end
        $display("Area is: %0.2f", get_area());
        $display("--------------------------------------------------------------------------------");
    endfunction

endclass



// ================================================================
// ============ RECTANGLE =========================================
// ================================================================
class rectangle_c extends Shape_c;

    // Zmieniamy konstruktor na 4 punkty
    function new(string name, real points[4][2]);
        super.new(name, points);
    endfunction

    // Obliczamy pole na podstawie 4 punktów
    function real get_area();
        real width, height;

        // Szerokość: od punktu 0 do 1 (dolna krawędź)
        width  = abs_func(points[1][0] - points[0][0]);

        // Wysokość: od punktu 0 do 3 (lewa krawędź)
        height = abs_func(points[3][1] - points[0][1]);

        return width * height;
    endfunction

endclass



// ================================================================
// ============ POLYGON ===========================================
// ================================================================
class polygon_c extends Shape_c;

    function new(string name, real points[$][2]);
        super.new(name, points);
    endfunction

    // Shoelace formula
    function real get_area();
        real area;
        int n = points.size();
        int i;
        area = 0;

        for (i = 0; i < n; i++) begin
            int j = (i + 1) % n;
            area += (points[i][0] * points[j][1]) - (points[j][0] * points[i][1]);
        end

        return 0.5 * abs_func(area);
    endfunction
endclass



// ================================================================
// ============ TRIANGLE ==========================================
// ================================================================
class triangle_c extends Shape_c;

    function new(string name, real points[3][2]);
        super.new(name, points);
    endfunction

    function real get_area();
        real x1, y1, x2, y2, x3, y3;

        x1 = points[0][0]; y1 = points[0][1];
        x2 = points[1][0]; y2 = points[1][1];
        x3 = points[2][0]; y3 = points[2][1];

        return 0.5 * abs_func(
            x1*(y2 - y3) +
            x2*(y3 - y1) +
            x3*(y1 - y2)
        );
    endfunction
endclass



// ================================================================
// ============ CIRCLE ============================================
// points[0] = center
// points[1] = point on radius
// ================================================================
class circle_c extends Shape_c;

    function new(string name, real points[2][2]);
        super.new(name, points);
    endfunction

    // radius = sqrt( dx^2 + dy^2 )
    function real get_radius();
        real dx, dy;
        dx = points[1][0] - points[0][0];
        dy = points[1][1] - points[0][1];
        return $sqrt(dx*dx + dy*dy);
    endfunction

    function real get_area();
        real r = get_radius();
        return 3.14159265358979 * r * r;
    endfunction

    function void print();
        real r = get_radius();
        $display("--------------------------------------------------------------------------------");
        $display("This is: circle");
        $display(" (%0.2f, %0.2f)", points[0][0], points[0][1]);
        $display(" radius: %0.2f", r);
        $display("Area is: %0.2f", get_area());
        $display("--------------------------------------------------------------------------------");
    endfunction

endclass



// ================================================================
// ============ SHAPE REPORTER ====================================
// ================================================================
class shape_reporter #(type T = Shape_c);

    protected static T shape_storage[$];

    static function void push_shape(T obj);
        shape_storage.push_back(obj);
    endfunction

    static function void report_shapes();

        if (shape_storage.size() == 0) begin
            $display("No shapes stored.\n");
            return;
        end

        $display("\n================ REPORT =================");

        foreach (shape_storage[i]) begin
            shape_storage[i].print();
        end
        $display("==========================================\n");
    endfunction

endclass



// ================================================================
// ============ SHAPE FACTORY =====================================
// ================================================================
class shape_factory;

    static function Shape_c make_shape(real pts[$][2]);
        Shape_c obj;

        case (pts.size())
            2: begin
                circle_c c = new("circle", pts);
                obj = c;
            end

            3: begin
                triangle_c t = new("triangle", pts);
                obj = t;
            end

            4: begin
                if (is_rectangle(pts)) begin
                    rectangle_c r = new("rectangle", pts);
                    obj = r;
                end else begin
                    polygon_c p = new("polygon", pts);
                    obj = p;
                end
            end

            default: begin
                polygon_c p = new("polygon", pts);
                obj = p;
            end
        endcase

        //shape_reporter#()::push_shape(obj);
        return obj;
    endfunction


    // rectangle detection (simplified)
    static function bit is_rectangle(real p[$][2]);
        real dx, dy;
        dx = abs_func(p[1][0] - p[0][0]);
        dy = abs_func(p[1][1] - p[0][1]); 

        if (dx != 0 && dy != 0)
            return 1;
        else
            return 0;
    endfunction

endclass



// ================================================================
// ============ TOP MODULE ========================================
// ================================================================
module top;
    int fd;
    string line;
    Shape_c s;
    shape_factory sf = new();
    shape_reporter#(Shape_c) sr = new();

    initial begin        
        fd = $fopen("lab04part1_shapes.txt", "r");
        if (!fd) begin
            $display("ERROR: Cannot open file!");
            $finish;
        end

        while ($fgets(line, fd)) begin
            real nums[$];
            real pts[$][2];
            int i;

            nums.delete();
            pts.delete();
            parse_points(line, nums);

`ifdef DEBUG
            $display("line: %s", line);
            $display("nums size: %0d", nums.size());
`endif
            
            for (i = 0; i < nums.size()/2; i++) begin
                pts.push_back('{nums[2*i], nums[2*i + 1]});
`ifdef DEBUG
                $display("Point %0d: (%0.2f, %0.2f)", i, nums[2*i], nums[2*i + 1]);
`endif
            end          

            s = sf.make_shape(pts);
            sr.push_shape(s);
            sr.report_shapes();
            


        end

        $fclose(fd);

        
        $finish;
    end

   function automatic void parse_points(string line, ref real values[$]);
        real val;
        int sp;
        string token;

        values.delete();
        //$display("Parsing line: '%s'", line);
        // Scan for floating point numbers
            begin
                automatic string num_str;
                for (int i = 0; i < line.len(); i++) begin
                    // Skip whitespace
                    while (i < line.len() && (line[i] inside {" ", "\t", "\n", "\r"})) begin
                        i++;
                    end

                    if (i >= line.len()) break;

                    // Extract number
                    num_str = "";

                    // Read the number (including sign and decimal point)
                    while (i < line.len() && (line[i] inside {"-", "."} || line[i] inside {["0" : "9"]})) begin
                        num_str = {num_str, line[i]};
                        i++;
                    end

                    if (num_str.len() > 0) begin
                        values.push_back(num_str.atoreal());
                    end

                    i--; // Adjust for loop increment
                end
            end

            //$display("Remaining line: '%s'", line);
    endfunction

endmodule
