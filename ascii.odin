import "core:fmt.odin"
import "core:os.odin"
import "core:strings.odin"
import "core:math.odin";

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
	projection: math.Mat4,
	close_window: bool,
	indices_count: i32,
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
	ascii_state.indices_count = cast(i32)len(indices);

	gl.BindVertexArray(ascii_state.vao);

	gl.EnableVertexAttribArray(0);
	gl.EnableVertexAttribArray(1);
	gl.EnableVertexAttribArray(2);
	gl.EnableVertexAttribArray(3);

	gl.BindBuffer(gl.ARRAY_BUFFER, ascii_state.vbo);
	gl.BufferData(gl.ARRAY_BUFFER, 4*2*len(vertices), &vertices[0], gl.STATIC_DRAW);
	gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 0, nil);

	gl.BindBuffer(gl.ARRAY_BUFFER, ascii_state.cbo);
	gl.BufferData(gl.ARRAY_BUFFER, len(ascii_state.glyphs)*28, nil, gl.DYNAMIC_DRAW);
	gl.VertexAttribPointer(1, 1, gl.UNSIGNED_INT, gl.FALSE, 0, nil);
	ptr := 4;
	gl.VertexAttribPointer(2, 3, gl.FLOAT, gl.FALSE, 0, (cast(^rawptr) &ptr)^);
	ptr = 16;
	gl.VertexAttribPointer(3, 3, gl.FLOAT, gl.FALSE, 0, (cast(^rawptr) &ptr)^);

	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ascii_state.ibo);
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(indices)*4, &indices[0], gl.STATIC_DRAW);

	gl.BindBuffer(gl.ARRAY_BUFFER, 0);

	free(vertices);
	free(indices);

	update_projection_matrix();	
}

update_projection_matrix :: proc() {
	ascii_state.projection = math.ortho3d(0, cast(f32)ascii_state.width, cast(f32)ascii_state.height, 0, -1, 1);
/*	ascii_state.projection[0][0] = 2.0 / cast(f32)(ascii_state.width-0);
	ascii_state.projection[1][1] = 2.0 / cast(f32)(ascii_state.height-0);
	ascii_state.projection[2][2] = -2.0 / cast(f32)(1.0 - -0.1);
	ascii_state.projection[3][3] = 1;

	ascii_state.projection[3][0] = -(cast(f32)(ascii_state.width+0)/cast(f32)(ascii_state.width-0));
	ascii_state.projection[3][0] = -(cast(f32)(ascii_state.height+0)/cast(f32)(ascii_state.height-0));
	ascii_state.projection[3][0] = -(cast(f32)(1+-1)/cast(f32)(1-(-1)));*/
	//ascii_state.projection = math.mat4_identity();
}

_init_callbacks :: proc() {
	glfw.SetWindowCloseCallback(ascii_state.window, proc(window: ^glfw.window) #cc_c {
		ascii_state.close_window = true;
	});

	glfw.SetFramebufferSizeCallback(ascii_state.window, proc(window: ^glfw.window, width, height: i32) #cc_c {
		gl.Viewport(0, 0, width, height);
	});
}

swap_buffers :: proc() {
	glfw.SwapBuffers(ascii_state.window);
	gl.Clear(gl.COLOR_BUFFER_BIT);
}

update_and_render :: proc() -> bool {
	gl.UseProgram(ascii_state.font_shader);
	//gl.UniformMatrix4fv(ascii_state.uniforms["projection"].location, 1, gl.FALSE, &ascii_state.projection[0][0]);
	proj := "projection\x00";
	gl.UniformMatrix4fv(gl.GetUniformLocation(ascii_state.font_shader, &proj[0]), 1, gl.FALSE, &ascii_state.projection[0][0]);

	cells_w := "cells_w\x00";
	cells_h := "cells_h\x00";
	gl.Uniform1i(gl.GetUniformLocation(ascii_state.font_shader, &cells_w[0]), cast(i32)ascii_state.font.cell_w);
	gl.Uniform1i(gl.GetUniformLocation(ascii_state.font_shader, &cells_h[0]), cast(i32)ascii_state.font.cell_h);

	gl.BindVertexArray(ascii_state.vao);

	gl.BindTexture(gl.TEXTURE_2D, ascii_state.font.texture);

	// Need to have a glyph for every vertex, not every character
	// aka every glyph needs a second copy
	gl.BindBuffer(gl.ARRAY_BUFFER, ascii_state.cbo);
	gl.BufferSubData(gl.ARRAY_BUFFER, 0, len(ascii_state.glyphs)*28, &ascii_state.glyphs[0]);

	gl.DrawElements(gl.TRIANGLES, ascii_state.indices_count, gl.UNSIGNED_INT, nil);

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
foreign_library "stb_image.lib";

foreign stb_image {
	stbi_load       :: proc(file: ^u8, x: ^i32, y: ^i32, n: ^i32, req_comp: i32) -> ^u8 #cc_c ---;
	stbi_image_free :: proc(data: ^u8) #cc_c ---;
}

load_font :: proc(path: string, cell_w: int, cell_h: int) -> Font {
	result: Font;

	result.cell_w = cell_w;
	result.cell_h = cell_h;

	fmt.println(stbi_load);
	fmt.println(stbi_image_free);

	w, h, c: i32;
	cpath := strings.new_c_string(path);
	defer free(cpath);
	data := stbi_load(cpath, &w, &h, &c, 4);
	defer stbi_image_free(data);

	fmt.println(gl.GenTextures);
	gl.GenTextures(1, &result.texture);
	fmt.println("am i dumb?");
	gl.BindTexture(gl.TEXTURE_2D, result.texture);

	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, w, h, 0, c == 4 ? gl.RGBA : gl.RGB, gl.UNSIGNED_BYTE, data);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
	// read and load texture

	return result;
}