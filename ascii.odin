import "core:fmt.odin"
import "core:os.odin"
import "core:strings.odin"

import "shared:odin-glfw/glfw.odin"
import "shared:odin-gl/gl.odin"

export "events.odin"

/*
TODO:
	- Create and open window
	- Get a queue and the event system working
	- On resize reallocate the cells and snap the window size to 
	  fit the cell grid.

	- Implement the ability to set a scale value, use float, prefer integer

*/

Color :: struct #packed {
	r, g, b: f32,
}

BLACK      := Color{0.0, 0.0, 0.0};
WHITE      := Color{1.0, 1.0, 1.0};
LIGHT_GRAY := Color{0.5, 0.5, 0.5};

Glyph :: struct #packed {
	char: u32 = ' ',
	fg: Color = Color{0.5, 0.5, 0.5},
	bg: Color = Color{0.0, 0.0, 0.0},
}

ascii_state: struct {
	window: ^glfw.window,
	width, height: int,
	font: Font,
	glyphs: []Glyph,
	font_shader: u32,
	vbo, cbo, ibo: u32,
	vao: u32,
	uniforms: map[string]gl.Uniform_Info,
	projection: [16]f32,
	close_window: bool,
	num_vertices: i32,
};

Font :: struct {
	cell_w: int,
	cell_h: int,
	texture: u32,
}

print_gl_info :: proc() {
	get_string :: proc(name: u32) -> string {
		cstr := gl.GetString(name);
		return strings.to_odin_string(cstr);
	}

	fmt.println("GL_RENDERER:", get_string(gl.RENDERER));

	fmt.println();
}

open_window :: proc(title: string, width: int, height: int, font: Font, vsync: bool = true, resizable: bool = false) -> bool {
	if glfw.Init() == 0 {
		fmt.printf("Failed to init GLFW!");
		return false;
	}

	ascii_state.font = font;
	ascii_state.width = width;
	ascii_state.height = height;

	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3);
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3);

	title_p := "placeholder\x00";
	ascii_state.window = glfw.CreateWindow(cast(i32) (width*font.cell_w), cast(i32) (height*font.cell_h), &title_p[0], nil, nil);
	if ascii_state.window == nil {
		fmt.printf("Failed to create glfw window!");
		return false;
	}

	glfw.MakeContextCurrent(ascii_state.window);
	set_proc_address :: proc(p: rawptr, name: string) { 
    	(cast(^rawptr)p)^ = rawptr(glfw.GetProcAddress(&name[0]));
	}
	gl.load_up_to(3, 3, set_proc_address);

	glfw.SwapInterval(1);

	_init_callbacks();

	print_gl_info();

	ascii_state.glyphs = make([]Glyph, width*height);

	/*ok: bool;
	ascii_state.font_shader, ok = gl.load_shaders("font.vert", "font.frag");
	if !ok {
		fmt.println("Failed to compile shader");
		os.exit(1);
	}*/
	ascii_state.font_shader = load_shader("font.vert", "font.frag");

	ascii_state.uniforms = gl.get_uniforms_from_program(ascii_state.font_shader);

	gl.ClearColor(1, 0, 1, 1);

	gl.GenBuffers(1, &ascii_state.vbo);
	gl.GenBuffers(1, &ascii_state.cbo);
	gl.GenBuffers(1, &ascii_state.ibo);
	gl.GenVertexArrays(1, &ascii_state.vao);	

	update_gl();

	return true;
}

update_gl :: proc() {
	vertices: [dynamic][2]f32;
	for y := 0; y < ascii_state.height; y += 1 {
		for x := 0; x < ascii_state.width; x += 1 {
			append(&vertices, [2]f32{cast(f32)(x+0), cast(f32)(y+0)});
			append(&vertices, [2]f32{cast(f32)(x+1), cast(f32)(y+0)});
			append(&vertices, [2]f32{cast(f32)(x+1), cast(f32)(y+1)});
			append(&vertices, [2]f32{cast(f32)(x+0), cast(f32)(y+1)});
		}
	}

	ascii_state.num_vertices = cast(i32)len(vertices);
	indices: [dynamic]u32;
	offset := 0;
	for i := 0; i < ascii_state.width*ascii_state.height; i += 1 {
		append(&indices, cast(u32)(offset + 0));
		append(&indices, cast(u32)(offset + 1));
		append(&indices, cast(u32)(offset + 2));
		append(&indices, cast(u32)(offset + 2));
		append(&indices, cast(u32)(offset + 3));
		append(&indices, cast(u32)(offset + 0));

		offset += 4;
	}

	gl.BindVertexArray(ascii_state.vao);

	gl.EnableVertexAttribArray(0);
	gl.EnableVertexAttribArray(1);
	gl.EnableVertexAttribArray(2);
	gl.EnableVertexAttribArray(3);

	gl.BindBuffer(gl.ARRAY_BUFFER, ascii_state.vbo);
	gl.BufferData(gl.ARRAY_BUFFER, len(vertices), &vertices[0], gl.STATIC_DRAW);
	gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 0, nil);

	gl.BindBuffer(gl.ARRAY_BUFFER, ascii_state.cbo);
	gl.BufferData(gl.ARRAY_BUFFER, 1, nil, gl.DYNAMIC_DRAW);
	gl.VertexAttribPointer(1, 1, gl.UNSIGNED_INT, gl.FALSE, 0, nil);
	ptr := 4;
	gl.VertexAttribPointer(2, 3, gl.FLOAT, gl.FALSE, 0, (cast(^rawptr) &ptr)^);
	ptr = 16;
	gl.VertexAttribPointer(3, 3, gl.FLOAT, gl.FALSE, 0, (cast(^rawptr) &ptr)^);

	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ascii_state.ibo);
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(indices), &indices[0], gl.STATIC_DRAW);

	gl.BindBuffer(gl.ARRAY_BUFFER, 0);

	free(vertices);
	free(indices);

	update_projection_matrix();	
}

update_projection_matrix :: proc() {
	window_width := ascii_state.width*ascii_state.font.cell_w;
	window_height := ascii_state.height*ascii_state.font.cell_h;

	ascii_state.projection[3 + 3 * 4] = 1;

	ascii_state.projection[0 + 0 * 4] = 2.0 / cast(f32)(window_width);
	ascii_state.projection[1 + 1 * 4] = 2.0 / -cast(f32)(window_height);
	ascii_state.projection[2 + 2 * 4] = 2.0 / cast(f32)(-1 - 1);

	ascii_state.projection[3 + 0 * 4] = (cast(f32)window_width) / (cast(f32)-window_width);
	ascii_state.projection[3 + 1 * 4] = (cast(f32)window_height) / (cast(f32)window_height);
	ascii_state.projection[3 + 2 * 4] = cast(f32)(1 + -1) / cast(f32)(-1 - 1);
}

_init_callbacks :: proc() {
	glfw.SetWindowCloseCallback(ascii_state.window, proc(window: ^glfw.window) #cc_c {
		ascii_state.close_window = true;
	});
}

swap_buffers :: proc() {
	glfw.SwapBuffers(ascii_state.window);
	gl.Clear(gl.COLOR_BUFFER_BIT);
}

update_and_render :: proc() -> bool {
	gl.BindVertexArray(ascii_state.vao);

	gl.UniformMatrix4fv(ascii_state.uniforms["projection"].location, 1, gl.FALSE, &ascii_state.projection[0]);

	gl.DrawElements(gl.TRIANGLES, ascii_state.num_vertices, gl.UNSIGNED_INT, nil);

	_update();
	return ascii_state.close_window;
}

_update :: proc() {
	glfw.PollEvents();
}

load_shader :: proc(vert, frag: string) -> u32 {
	result := gl.CreateProgram();

	add_shader :: proc(program: u32, kind: u32, path: string) {
		data, ok := os.read_entire_file(path);
		if !ok {
			fmt.printf("Failed to read shader '%s'", path);
			os.exit(1);
		}

		shader := gl.CreateShader(kind);
		length := cast(i32)len(data);
		c_data := &data[0];
		gl.ShaderSource(shader, 1, &c_data, &length);
		gl.CompileShader(shader);

		glerr: i32;
		gl.GetShaderiv(shader, gl.COMPILE_STATUS, &glerr);
		if glerr != gl.TRUE {
			fmt.printf("Failed to compile shader '%s'!\n", path);
			buffer: [4096]u8;
			gl.GetShaderInfoLog(shader, 4096, nil, &buffer[0]);
			fmt.printf("GL_ERROR:\n%s\n", strings.to_odin_string(&buffer[0]));
			os.exit(2);
		}

		gl.AttachShader(program, shader);
	}

	add_shader(result, gl.VERTEX_SHADER, vert);
	add_shader(result, gl.FRAGMENT_SHADER, frag);

	gl.LinkProgram(result);
	err: i32;
	gl.GetProgramiv(result, gl.LINK_STATUS, &err);
	if err != gl.TRUE {
		fmt.printf("Failed to link program with vertex shader '%s' and fragment shader '%s'!\n", vert, frag);
		os.exit(3);
	}

	gl.ValidateProgram(result);
	gl.GetProgramiv(result, gl.VALIDATE_STATUS, &err);
	if err != gl.TRUE {
		fmt.printf("Failed to validate program with vertex shader '%s' and fragment shader '%s'!\n", vert, frag);
		os.exit(4);
	}

	return result;
}

// Replace the current font and recalculate window size, cell sizes, etc.
// update_projection_matrix
//update_font :: proc()

load_font :: proc(path: string, cell_w: int, cell_h: int) -> Font {
	result: Font;

	result.cell_w = cell_w;
	result.cell_h = cell_h;

	// read and load texture

	return result;
}