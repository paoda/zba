//
// This code file is licenced under any of Public Domain, WTFPL or CC0.
// There are no restrictions in the use of this file.
//

//
// Generation parameters:
// API:        GL_VERSION_3_3
// Profile:    core
// Extensions:
//

//
// This file was generated with the following command line:
// generator C:\Users\paoda\dev\open\zig-opengl\bin\Debug\net6.0\generator.dll .\OpenGL-Registry\xml\gl.xml gl.zig GL_VERSION_3_3
//

const std = @import("std");
const builtin = @import("builtin");
const log = std.log.scoped(.OpenGL);

pub const FunctionPointer: type = blk: {
    const BaseFunc = fn (u32) callconv(.C) u32;
    const SpecializedFnPtr = FnPtr(BaseFunc);
    const fnptr_type = @typeInfo(SpecializedFnPtr);
    var generic_type = fnptr_type;
    std.debug.assert(generic_type.Pointer.size == .One);
    generic_type.Pointer.child = anyopaque;
    break :blk @Type(generic_type);
};

pub const GLenum = c_uint;
pub const GLboolean = u8;
pub const GLbitfield = c_uint;
pub const GLbyte = i8;
pub const GLubyte = u8;
pub const GLshort = i16;
pub const GLushort = u16;
pub const GLint = c_int;
pub const GLuint = c_uint;
pub const GLclampx = i32;
pub const GLsizei = c_int;
pub const GLfloat = f32;
pub const GLclampf = f32;
pub const GLdouble = f64;
pub const GLclampd = f64;
pub const GLeglClientBufferEXT = void;
pub const GLeglImageOES = void;
pub const GLchar = u8;
pub const GLcharARB = u8;

pub const GLhandleARB = if (builtin.os.tag == .macos) *anyopaque else c_uint;

pub const GLhalf = u16;
pub const GLhalfARB = u16;
pub const GLfixed = i32;
pub const GLintptr = usize;
pub const GLintptrARB = usize;
pub const GLsizeiptr = isize;
pub const GLsizeiptrARB = isize;
pub const GLint64 = i64;
pub const GLint64EXT = i64;
pub const GLuint64 = u64;
pub const GLuint64EXT = u64;

pub const GLsync = *opaque {};

pub const _cl_context = opaque {};
pub const _cl_event = opaque {};

pub const GLDEBUGPROC = FnPtr(fn (source: GLenum, _type: GLenum, id: GLuint, severity: GLenum, length: GLsizei, message: [*:0]const u8, userParam: ?*anyopaque) callconv(.C) void);
pub const GLDEBUGPROCARB = FnPtr(fn (source: GLenum, _type: GLenum, id: GLuint, severity: GLenum, length: GLsizei, message: [*:0]const u8, userParam: ?*anyopaque) callconv(.C) void);
pub const GLDEBUGPROCKHR = FnPtr(fn (source: GLenum, _type: GLenum, id: GLuint, severity: GLenum, length: GLsizei, message: [*:0]const u8, userParam: ?*anyopaque) callconv(.C) void);

pub const GLDEBUGPROCAMD = FnPtr(fn (id: GLuint, category: GLenum, severity: GLenum, length: GLsizei, message: [*:0]const u8, userParam: ?*anyopaque) callconv(.C) void);

pub const GLhalfNV = u16;
pub const GLvdpauSurfaceNV = GLintptr;
pub const GLVULKANPROCNV = *const fn () callconv(.C) void;

fn FnPtr(comptime Fn: type) type {
    return if (@import("builtin").zig_backend != .stage1)
        *const Fn
    else
        Fn;
}

pub const DEPTH_BUFFER_BIT = 0x00000100;
pub const STENCIL_BUFFER_BIT = 0x00000400;
pub const COLOR_BUFFER_BIT = 0x00004000;
pub const FALSE = 0;
pub const TRUE = 1;
pub const POINTS = 0x0000;
pub const LINES = 0x0001;
pub const LINE_LOOP = 0x0002;
pub const LINE_STRIP = 0x0003;
pub const TRIANGLES = 0x0004;
pub const TRIANGLE_STRIP = 0x0005;
pub const TRIANGLE_FAN = 0x0006;
pub const NEVER = 0x0200;
pub const LESS = 0x0201;
pub const EQUAL = 0x0202;
pub const LEQUAL = 0x0203;
pub const GREATER = 0x0204;
pub const NOTEQUAL = 0x0205;
pub const GEQUAL = 0x0206;
pub const ALWAYS = 0x0207;
pub const ZERO = 0;
pub const ONE = 1;
pub const SRC_COLOR = 0x0300;
pub const ONE_MINUS_SRC_COLOR = 0x0301;
pub const SRC_ALPHA = 0x0302;
pub const ONE_MINUS_SRC_ALPHA = 0x0303;
pub const DST_ALPHA = 0x0304;
pub const ONE_MINUS_DST_ALPHA = 0x0305;
pub const DST_COLOR = 0x0306;
pub const ONE_MINUS_DST_COLOR = 0x0307;
pub const SRC_ALPHA_SATURATE = 0x0308;
pub const NONE = 0;
pub const FRONT_LEFT = 0x0400;
pub const FRONT_RIGHT = 0x0401;
pub const BACK_LEFT = 0x0402;
pub const BACK_RIGHT = 0x0403;
pub const FRONT = 0x0404;
pub const BACK = 0x0405;
pub const LEFT = 0x0406;
pub const RIGHT = 0x0407;
pub const FRONT_AND_BACK = 0x0408;
pub const NO_ERROR = 0;
pub const INVALID_ENUM = 0x0500;
pub const INVALID_VALUE = 0x0501;
pub const INVALID_OPERATION = 0x0502;
pub const OUT_OF_MEMORY = 0x0505;
pub const CW = 0x0900;
pub const CCW = 0x0901;
pub const POINT_SIZE = 0x0B11;
pub const POINT_SIZE_RANGE = 0x0B12;
pub const POINT_SIZE_GRANULARITY = 0x0B13;
pub const LINE_SMOOTH = 0x0B20;
pub const LINE_WIDTH = 0x0B21;
pub const LINE_WIDTH_RANGE = 0x0B22;
pub const LINE_WIDTH_GRANULARITY = 0x0B23;
pub const POLYGON_MODE = 0x0B40;
pub const POLYGON_SMOOTH = 0x0B41;
pub const CULL_FACE = 0x0B44;
pub const CULL_FACE_MODE = 0x0B45;
pub const FRONT_FACE = 0x0B46;
pub const DEPTH_RANGE = 0x0B70;
pub const DEPTH_TEST = 0x0B71;
pub const DEPTH_WRITEMASK = 0x0B72;
pub const DEPTH_CLEAR_VALUE = 0x0B73;
pub const DEPTH_FUNC = 0x0B74;
pub const STENCIL_TEST = 0x0B90;
pub const STENCIL_CLEAR_VALUE = 0x0B91;
pub const STENCIL_FUNC = 0x0B92;
pub const STENCIL_VALUE_MASK = 0x0B93;
pub const STENCIL_FAIL = 0x0B94;
pub const STENCIL_PASS_DEPTH_FAIL = 0x0B95;
pub const STENCIL_PASS_DEPTH_PASS = 0x0B96;
pub const STENCIL_REF = 0x0B97;
pub const STENCIL_WRITEMASK = 0x0B98;
pub const VIEWPORT = 0x0BA2;
pub const DITHER = 0x0BD0;
pub const BLEND_DST = 0x0BE0;
pub const BLEND_SRC = 0x0BE1;
pub const BLEND = 0x0BE2;
pub const LOGIC_OP_MODE = 0x0BF0;
pub const DRAW_BUFFER = 0x0C01;
pub const READ_BUFFER = 0x0C02;
pub const SCISSOR_BOX = 0x0C10;
pub const SCISSOR_TEST = 0x0C11;
pub const COLOR_CLEAR_VALUE = 0x0C22;
pub const COLOR_WRITEMASK = 0x0C23;
pub const DOUBLEBUFFER = 0x0C32;
pub const STEREO = 0x0C33;
pub const LINE_SMOOTH_HINT = 0x0C52;
pub const POLYGON_SMOOTH_HINT = 0x0C53;
pub const UNPACK_SWAP_BYTES = 0x0CF0;
pub const UNPACK_LSB_FIRST = 0x0CF1;
pub const UNPACK_ROW_LENGTH = 0x0CF2;
pub const UNPACK_SKIP_ROWS = 0x0CF3;
pub const UNPACK_SKIP_PIXELS = 0x0CF4;
pub const UNPACK_ALIGNMENT = 0x0CF5;
pub const PACK_SWAP_BYTES = 0x0D00;
pub const PACK_LSB_FIRST = 0x0D01;
pub const PACK_ROW_LENGTH = 0x0D02;
pub const PACK_SKIP_ROWS = 0x0D03;
pub const PACK_SKIP_PIXELS = 0x0D04;
pub const PACK_ALIGNMENT = 0x0D05;
pub const MAX_TEXTURE_SIZE = 0x0D33;
pub const MAX_VIEWPORT_DIMS = 0x0D3A;
pub const SUBPIXEL_BITS = 0x0D50;
pub const TEXTURE_1D = 0x0DE0;
pub const TEXTURE_2D = 0x0DE1;
pub const TEXTURE_WIDTH = 0x1000;
pub const TEXTURE_HEIGHT = 0x1001;
pub const TEXTURE_BORDER_COLOR = 0x1004;
pub const DONT_CARE = 0x1100;
pub const FASTEST = 0x1101;
pub const NICEST = 0x1102;
pub const BYTE = 0x1400;
pub const UNSIGNED_BYTE = 0x1401;
pub const SHORT = 0x1402;
pub const UNSIGNED_SHORT = 0x1403;
pub const INT = 0x1404;
pub const UNSIGNED_INT = 0x1405;
pub const FLOAT = 0x1406;
pub const CLEAR = 0x1500;
pub const AND = 0x1501;
pub const AND_REVERSE = 0x1502;
pub const COPY = 0x1503;
pub const AND_INVERTED = 0x1504;
pub const NOOP = 0x1505;
pub const XOR = 0x1506;
pub const OR = 0x1507;
pub const NOR = 0x1508;
pub const EQUIV = 0x1509;
pub const INVERT = 0x150A;
pub const OR_REVERSE = 0x150B;
pub const COPY_INVERTED = 0x150C;
pub const OR_INVERTED = 0x150D;
pub const NAND = 0x150E;
pub const SET = 0x150F;
pub const TEXTURE = 0x1702;
pub const COLOR = 0x1800;
pub const DEPTH = 0x1801;
pub const STENCIL = 0x1802;
pub const STENCIL_INDEX = 0x1901;
pub const DEPTH_COMPONENT = 0x1902;
pub const RED = 0x1903;
pub const GREEN = 0x1904;
pub const BLUE = 0x1905;
pub const ALPHA = 0x1906;
pub const RGB = 0x1907;
pub const RGBA = 0x1908;
pub const POINT = 0x1B00;
pub const LINE = 0x1B01;
pub const FILL = 0x1B02;
pub const KEEP = 0x1E00;
pub const REPLACE = 0x1E01;
pub const INCR = 0x1E02;
pub const DECR = 0x1E03;
pub const VENDOR = 0x1F00;
pub const RENDERER = 0x1F01;
pub const VERSION = 0x1F02;
pub const EXTENSIONS = 0x1F03;
pub const NEAREST = 0x2600;
pub const LINEAR = 0x2601;
pub const NEAREST_MIPMAP_NEAREST = 0x2700;
pub const LINEAR_MIPMAP_NEAREST = 0x2701;
pub const NEAREST_MIPMAP_LINEAR = 0x2702;
pub const LINEAR_MIPMAP_LINEAR = 0x2703;
pub const TEXTURE_MAG_FILTER = 0x2800;
pub const TEXTURE_MIN_FILTER = 0x2801;
pub const TEXTURE_WRAP_S = 0x2802;
pub const TEXTURE_WRAP_T = 0x2803;
pub const REPEAT = 0x2901;
pub const COLOR_LOGIC_OP = 0x0BF2;
pub const POLYGON_OFFSET_UNITS = 0x2A00;
pub const POLYGON_OFFSET_POINT = 0x2A01;
pub const POLYGON_OFFSET_LINE = 0x2A02;
pub const POLYGON_OFFSET_FILL = 0x8037;
pub const POLYGON_OFFSET_FACTOR = 0x8038;
pub const TEXTURE_BINDING_1D = 0x8068;
pub const TEXTURE_BINDING_2D = 0x8069;
pub const TEXTURE_INTERNAL_FORMAT = 0x1003;
pub const TEXTURE_RED_SIZE = 0x805C;
pub const TEXTURE_GREEN_SIZE = 0x805D;
pub const TEXTURE_BLUE_SIZE = 0x805E;
pub const TEXTURE_ALPHA_SIZE = 0x805F;
pub const DOUBLE = 0x140A;
pub const PROXY_TEXTURE_1D = 0x8063;
pub const PROXY_TEXTURE_2D = 0x8064;
pub const R3_G3_B2 = 0x2A10;
pub const RGB4 = 0x804F;
pub const RGB5 = 0x8050;
pub const RGB8 = 0x8051;
pub const RGB10 = 0x8052;
pub const RGB12 = 0x8053;
pub const RGB16 = 0x8054;
pub const RGBA2 = 0x8055;
pub const RGBA4 = 0x8056;
pub const RGB5_A1 = 0x8057;
pub const RGBA8 = 0x8058;
pub const RGB10_A2 = 0x8059;
pub const RGBA12 = 0x805A;
pub const RGBA16 = 0x805B;
pub const UNSIGNED_BYTE_3_3_2 = 0x8032;
pub const UNSIGNED_SHORT_4_4_4_4 = 0x8033;
pub const UNSIGNED_SHORT_5_5_5_1 = 0x8034;
pub const UNSIGNED_INT_8_8_8_8 = 0x8035;
pub const UNSIGNED_INT_10_10_10_2 = 0x8036;
pub const TEXTURE_BINDING_3D = 0x806A;
pub const PACK_SKIP_IMAGES = 0x806B;
pub const PACK_IMAGE_HEIGHT = 0x806C;
pub const UNPACK_SKIP_IMAGES = 0x806D;
pub const UNPACK_IMAGE_HEIGHT = 0x806E;
pub const TEXTURE_3D = 0x806F;
pub const PROXY_TEXTURE_3D = 0x8070;
pub const TEXTURE_DEPTH = 0x8071;
pub const TEXTURE_WRAP_R = 0x8072;
pub const MAX_3D_TEXTURE_SIZE = 0x8073;
pub const UNSIGNED_BYTE_2_3_3_REV = 0x8362;
pub const UNSIGNED_SHORT_5_6_5 = 0x8363;
pub const UNSIGNED_SHORT_5_6_5_REV = 0x8364;
pub const UNSIGNED_SHORT_4_4_4_4_REV = 0x8365;
pub const UNSIGNED_SHORT_1_5_5_5_REV = 0x8366;
pub const UNSIGNED_INT_8_8_8_8_REV = 0x8367;
pub const UNSIGNED_INT_2_10_10_10_REV = 0x8368;
pub const BGR = 0x80E0;
pub const BGRA = 0x80E1;
pub const MAX_ELEMENTS_VERTICES = 0x80E8;
pub const MAX_ELEMENTS_INDICES = 0x80E9;
pub const CLAMP_TO_EDGE = 0x812F;
pub const TEXTURE_MIN_LOD = 0x813A;
pub const TEXTURE_MAX_LOD = 0x813B;
pub const TEXTURE_BASE_LEVEL = 0x813C;
pub const TEXTURE_MAX_LEVEL = 0x813D;
pub const SMOOTH_POINT_SIZE_RANGE = 0x0B12;
pub const SMOOTH_POINT_SIZE_GRANULARITY = 0x0B13;
pub const SMOOTH_LINE_WIDTH_RANGE = 0x0B22;
pub const SMOOTH_LINE_WIDTH_GRANULARITY = 0x0B23;
pub const ALIASED_LINE_WIDTH_RANGE = 0x846E;
pub const TEXTURE0 = 0x84C0;
pub const TEXTURE1 = 0x84C1;
pub const TEXTURE2 = 0x84C2;
pub const TEXTURE3 = 0x84C3;
pub const TEXTURE4 = 0x84C4;
pub const TEXTURE5 = 0x84C5;
pub const TEXTURE6 = 0x84C6;
pub const TEXTURE7 = 0x84C7;
pub const TEXTURE8 = 0x84C8;
pub const TEXTURE9 = 0x84C9;
pub const TEXTURE10 = 0x84CA;
pub const TEXTURE11 = 0x84CB;
pub const TEXTURE12 = 0x84CC;
pub const TEXTURE13 = 0x84CD;
pub const TEXTURE14 = 0x84CE;
pub const TEXTURE15 = 0x84CF;
pub const TEXTURE16 = 0x84D0;
pub const TEXTURE17 = 0x84D1;
pub const TEXTURE18 = 0x84D2;
pub const TEXTURE19 = 0x84D3;
pub const TEXTURE20 = 0x84D4;
pub const TEXTURE21 = 0x84D5;
pub const TEXTURE22 = 0x84D6;
pub const TEXTURE23 = 0x84D7;
pub const TEXTURE24 = 0x84D8;
pub const TEXTURE25 = 0x84D9;
pub const TEXTURE26 = 0x84DA;
pub const TEXTURE27 = 0x84DB;
pub const TEXTURE28 = 0x84DC;
pub const TEXTURE29 = 0x84DD;
pub const TEXTURE30 = 0x84DE;
pub const TEXTURE31 = 0x84DF;
pub const ACTIVE_TEXTURE = 0x84E0;
pub const MULTISAMPLE = 0x809D;
pub const SAMPLE_ALPHA_TO_COVERAGE = 0x809E;
pub const SAMPLE_ALPHA_TO_ONE = 0x809F;
pub const SAMPLE_COVERAGE = 0x80A0;
pub const SAMPLE_BUFFERS = 0x80A8;
pub const SAMPLES = 0x80A9;
pub const SAMPLE_COVERAGE_VALUE = 0x80AA;
pub const SAMPLE_COVERAGE_INVERT = 0x80AB;
pub const TEXTURE_CUBE_MAP = 0x8513;
pub const TEXTURE_BINDING_CUBE_MAP = 0x8514;
pub const TEXTURE_CUBE_MAP_POSITIVE_X = 0x8515;
pub const TEXTURE_CUBE_MAP_NEGATIVE_X = 0x8516;
pub const TEXTURE_CUBE_MAP_POSITIVE_Y = 0x8517;
pub const TEXTURE_CUBE_MAP_NEGATIVE_Y = 0x8518;
pub const TEXTURE_CUBE_MAP_POSITIVE_Z = 0x8519;
pub const TEXTURE_CUBE_MAP_NEGATIVE_Z = 0x851A;
pub const PROXY_TEXTURE_CUBE_MAP = 0x851B;
pub const MAX_CUBE_MAP_TEXTURE_SIZE = 0x851C;
pub const COMPRESSED_RGB = 0x84ED;
pub const COMPRESSED_RGBA = 0x84EE;
pub const TEXTURE_COMPRESSION_HINT = 0x84EF;
pub const TEXTURE_COMPRESSED_IMAGE_SIZE = 0x86A0;
pub const TEXTURE_COMPRESSED = 0x86A1;
pub const NUM_COMPRESSED_TEXTURE_FORMATS = 0x86A2;
pub const COMPRESSED_TEXTURE_FORMATS = 0x86A3;
pub const CLAMP_TO_BORDER = 0x812D;
pub const INT_2_10_10_10_REV = 0x8D9F;
pub const TIMESTAMP = 0x8E28;
pub const TIME_ELAPSED = 0x88BF;
pub const TEXTURE_SWIZZLE_RGBA = 0x8E46;
pub const TEXTURE_SWIZZLE_A = 0x8E45;
pub const TEXTURE_SWIZZLE_B = 0x8E44;
pub const TEXTURE_SWIZZLE_G = 0x8E43;
pub const TEXTURE_SWIZZLE_R = 0x8E42;
pub const RGB10_A2UI = 0x906F;
pub const BLEND_DST_RGB = 0x80C8;
pub const BLEND_SRC_RGB = 0x80C9;
pub const BLEND_DST_ALPHA = 0x80CA;
pub const BLEND_SRC_ALPHA = 0x80CB;
pub const POINT_FADE_THRESHOLD_SIZE = 0x8128;
pub const DEPTH_COMPONENT16 = 0x81A5;
pub const DEPTH_COMPONENT24 = 0x81A6;
pub const DEPTH_COMPONENT32 = 0x81A7;
pub const MIRRORED_REPEAT = 0x8370;
pub const MAX_TEXTURE_LOD_BIAS = 0x84FD;
pub const TEXTURE_LOD_BIAS = 0x8501;
pub const INCR_WRAP = 0x8507;
pub const DECR_WRAP = 0x8508;
pub const TEXTURE_DEPTH_SIZE = 0x884A;
pub const TEXTURE_COMPARE_MODE = 0x884C;
pub const TEXTURE_COMPARE_FUNC = 0x884D;
pub const SAMPLER_BINDING = 0x8919;
pub const ANY_SAMPLES_PASSED = 0x8C2F;
pub const MAX_DUAL_SOURCE_DRAW_BUFFERS = 0x88FC;
pub const ONE_MINUS_SRC1_ALPHA = 0x88FB;
pub const ONE_MINUS_SRC1_COLOR = 0x88FA;
pub const SRC1_COLOR = 0x88F9;
pub const VERTEX_ATTRIB_ARRAY_DIVISOR = 0x88FE;
pub const MAX_INTEGER_SAMPLES = 0x9110;
pub const MAX_DEPTH_TEXTURE_SAMPLES = 0x910F;
pub const MAX_COLOR_TEXTURE_SAMPLES = 0x910E;
pub const UNSIGNED_INT_SAMPLER_2D_MULTISAMPLE_ARRAY = 0x910D;
pub const INT_SAMPLER_2D_MULTISAMPLE_ARRAY = 0x910C;
pub const SAMPLER_2D_MULTISAMPLE_ARRAY = 0x910B;
pub const UNSIGNED_INT_SAMPLER_2D_MULTISAMPLE = 0x910A;
pub const INT_SAMPLER_2D_MULTISAMPLE = 0x9109;
pub const SAMPLER_2D_MULTISAMPLE = 0x9108;
pub const TEXTURE_FIXED_SAMPLE_LOCATIONS = 0x9107;
pub const TEXTURE_SAMPLES = 0x9106;
pub const TEXTURE_BINDING_2D_MULTISAMPLE_ARRAY = 0x9105;
pub const TEXTURE_BINDING_2D_MULTISAMPLE = 0x9104;
pub const PROXY_TEXTURE_2D_MULTISAMPLE_ARRAY = 0x9103;
pub const TEXTURE_2D_MULTISAMPLE_ARRAY = 0x9102;
pub const PROXY_TEXTURE_2D_MULTISAMPLE = 0x9101;
pub const TEXTURE_2D_MULTISAMPLE = 0x9100;
pub const MAX_SAMPLE_MASK_WORDS = 0x8E59;
pub const SAMPLE_MASK_VALUE = 0x8E52;
pub const SAMPLE_MASK = 0x8E51;
pub const SAMPLE_POSITION = 0x8E50;
pub const SYNC_FLUSH_COMMANDS_BIT = 0x00000001;
pub const TIMEOUT_IGNORED = 0xFFFFFFFFFFFFFFFF;
pub const WAIT_FAILED = 0x911D;
pub const CONDITION_SATISFIED = 0x911C;
pub const TIMEOUT_EXPIRED = 0x911B;
pub const ALREADY_SIGNALED = 0x911A;
pub const SIGNALED = 0x9119;
pub const UNSIGNALED = 0x9118;
pub const SYNC_GPU_COMMANDS_COMPLETE = 0x9117;
pub const BLEND_COLOR = 0x8005;
pub const BLEND_EQUATION = 0x8009;
pub const CONSTANT_COLOR = 0x8001;
pub const ONE_MINUS_CONSTANT_COLOR = 0x8002;
pub const CONSTANT_ALPHA = 0x8003;
pub const ONE_MINUS_CONSTANT_ALPHA = 0x8004;
pub const FUNC_ADD = 0x8006;
pub const FUNC_REVERSE_SUBTRACT = 0x800B;
pub const FUNC_SUBTRACT = 0x800A;
pub const MIN = 0x8007;
pub const MAX = 0x8008;
pub const BUFFER_SIZE = 0x8764;
pub const BUFFER_USAGE = 0x8765;
pub const QUERY_COUNTER_BITS = 0x8864;
pub const CURRENT_QUERY = 0x8865;
pub const QUERY_RESULT = 0x8866;
pub const QUERY_RESULT_AVAILABLE = 0x8867;
pub const ARRAY_BUFFER = 0x8892;
pub const ELEMENT_ARRAY_BUFFER = 0x8893;
pub const ARRAY_BUFFER_BINDING = 0x8894;
pub const ELEMENT_ARRAY_BUFFER_BINDING = 0x8895;
pub const VERTEX_ATTRIB_ARRAY_BUFFER_BINDING = 0x889F;
pub const READ_ONLY = 0x88B8;
pub const WRITE_ONLY = 0x88B9;
pub const READ_WRITE = 0x88BA;
pub const BUFFER_ACCESS = 0x88BB;
pub const BUFFER_MAPPED = 0x88BC;
pub const BUFFER_MAP_POINTER = 0x88BD;
pub const STREAM_DRAW = 0x88E0;
pub const STREAM_READ = 0x88E1;
pub const STREAM_COPY = 0x88E2;
pub const STATIC_DRAW = 0x88E4;
pub const STATIC_READ = 0x88E5;
pub const STATIC_COPY = 0x88E6;
pub const DYNAMIC_DRAW = 0x88E8;
pub const DYNAMIC_READ = 0x88E9;
pub const DYNAMIC_COPY = 0x88EA;
pub const SAMPLES_PASSED = 0x8914;
pub const SRC1_ALPHA = 0x8589;
pub const SYNC_FENCE = 0x9116;
pub const SYNC_FLAGS = 0x9115;
pub const SYNC_STATUS = 0x9114;
pub const SYNC_CONDITION = 0x9113;
pub const OBJECT_TYPE = 0x9112;
pub const MAX_SERVER_WAIT_TIMEOUT = 0x9111;
pub const TEXTURE_CUBE_MAP_SEAMLESS = 0x884F;
pub const PROVOKING_VERTEX = 0x8E4F;
pub const LAST_VERTEX_CONVENTION = 0x8E4E;
pub const FIRST_VERTEX_CONVENTION = 0x8E4D;
pub const QUADS_FOLLOW_PROVOKING_VERTEX_CONVENTION = 0x8E4C;
pub const DEPTH_CLAMP = 0x864F;
pub const CONTEXT_PROFILE_MASK = 0x9126;
pub const MAX_FRAGMENT_INPUT_COMPONENTS = 0x9125;
pub const MAX_GEOMETRY_OUTPUT_COMPONENTS = 0x9124;
pub const MAX_GEOMETRY_INPUT_COMPONENTS = 0x9123;
pub const MAX_VERTEX_OUTPUT_COMPONENTS = 0x9122;
pub const BLEND_EQUATION_RGB = 0x8009;
pub const VERTEX_ATTRIB_ARRAY_ENABLED = 0x8622;
pub const VERTEX_ATTRIB_ARRAY_SIZE = 0x8623;
pub const VERTEX_ATTRIB_ARRAY_STRIDE = 0x8624;
pub const VERTEX_ATTRIB_ARRAY_TYPE = 0x8625;
pub const CURRENT_VERTEX_ATTRIB = 0x8626;
pub const VERTEX_PROGRAM_POINT_SIZE = 0x8642;
pub const VERTEX_ATTRIB_ARRAY_POINTER = 0x8645;
pub const STENCIL_BACK_FUNC = 0x8800;
pub const STENCIL_BACK_FAIL = 0x8801;
pub const STENCIL_BACK_PASS_DEPTH_FAIL = 0x8802;
pub const STENCIL_BACK_PASS_DEPTH_PASS = 0x8803;
pub const MAX_DRAW_BUFFERS = 0x8824;
pub const DRAW_BUFFER0 = 0x8825;
pub const DRAW_BUFFER1 = 0x8826;
pub const DRAW_BUFFER2 = 0x8827;
pub const DRAW_BUFFER3 = 0x8828;
pub const DRAW_BUFFER4 = 0x8829;
pub const DRAW_BUFFER5 = 0x882A;
pub const DRAW_BUFFER6 = 0x882B;
pub const DRAW_BUFFER7 = 0x882C;
pub const DRAW_BUFFER8 = 0x882D;
pub const DRAW_BUFFER9 = 0x882E;
pub const DRAW_BUFFER10 = 0x882F;
pub const DRAW_BUFFER11 = 0x8830;
pub const DRAW_BUFFER12 = 0x8831;
pub const DRAW_BUFFER13 = 0x8832;
pub const DRAW_BUFFER14 = 0x8833;
pub const DRAW_BUFFER15 = 0x8834;
pub const BLEND_EQUATION_ALPHA = 0x883D;
pub const MAX_VERTEX_ATTRIBS = 0x8869;
pub const VERTEX_ATTRIB_ARRAY_NORMALIZED = 0x886A;
pub const MAX_TEXTURE_IMAGE_UNITS = 0x8872;
pub const FRAGMENT_SHADER = 0x8B30;
pub const VERTEX_SHADER = 0x8B31;
pub const MAX_FRAGMENT_UNIFORM_COMPONENTS = 0x8B49;
pub const MAX_VERTEX_UNIFORM_COMPONENTS = 0x8B4A;
pub const MAX_VARYING_FLOATS = 0x8B4B;
pub const MAX_VERTEX_TEXTURE_IMAGE_UNITS = 0x8B4C;
pub const MAX_COMBINED_TEXTURE_IMAGE_UNITS = 0x8B4D;
pub const SHADER_TYPE = 0x8B4F;
pub const FLOAT_VEC2 = 0x8B50;
pub const FLOAT_VEC3 = 0x8B51;
pub const FLOAT_VEC4 = 0x8B52;
pub const INT_VEC2 = 0x8B53;
pub const INT_VEC3 = 0x8B54;
pub const INT_VEC4 = 0x8B55;
pub const BOOL = 0x8B56;
pub const BOOL_VEC2 = 0x8B57;
pub const BOOL_VEC3 = 0x8B58;
pub const BOOL_VEC4 = 0x8B59;
pub const FLOAT_MAT2 = 0x8B5A;
pub const FLOAT_MAT3 = 0x8B5B;
pub const FLOAT_MAT4 = 0x8B5C;
pub const SAMPLER_1D = 0x8B5D;
pub const SAMPLER_2D = 0x8B5E;
pub const SAMPLER_3D = 0x8B5F;
pub const SAMPLER_CUBE = 0x8B60;
pub const SAMPLER_1D_SHADOW = 0x8B61;
pub const SAMPLER_2D_SHADOW = 0x8B62;
pub const DELETE_STATUS = 0x8B80;
pub const COMPILE_STATUS = 0x8B81;
pub const LINK_STATUS = 0x8B82;
pub const VALIDATE_STATUS = 0x8B83;
pub const INFO_LOG_LENGTH = 0x8B84;
pub const ATTACHED_SHADERS = 0x8B85;
pub const ACTIVE_UNIFORMS = 0x8B86;
pub const ACTIVE_UNIFORM_MAX_LENGTH = 0x8B87;
pub const SHADER_SOURCE_LENGTH = 0x8B88;
pub const ACTIVE_ATTRIBUTES = 0x8B89;
pub const ACTIVE_ATTRIBUTE_MAX_LENGTH = 0x8B8A;
pub const FRAGMENT_SHADER_DERIVATIVE_HINT = 0x8B8B;
pub const SHADING_LANGUAGE_VERSION = 0x8B8C;
pub const CURRENT_PROGRAM = 0x8B8D;
pub const POINT_SPRITE_COORD_ORIGIN = 0x8CA0;
pub const LOWER_LEFT = 0x8CA1;
pub const UPPER_LEFT = 0x8CA2;
pub const STENCIL_BACK_REF = 0x8CA3;
pub const STENCIL_BACK_VALUE_MASK = 0x8CA4;
pub const STENCIL_BACK_WRITEMASK = 0x8CA5;
pub const MAX_GEOMETRY_TOTAL_OUTPUT_COMPONENTS = 0x8DE1;
pub const MAX_GEOMETRY_OUTPUT_VERTICES = 0x8DE0;
pub const MAX_GEOMETRY_UNIFORM_COMPONENTS = 0x8DDF;
pub const GEOMETRY_OUTPUT_TYPE = 0x8918;
pub const PIXEL_PACK_BUFFER = 0x88EB;
pub const PIXEL_UNPACK_BUFFER = 0x88EC;
pub const PIXEL_PACK_BUFFER_BINDING = 0x88ED;
pub const PIXEL_UNPACK_BUFFER_BINDING = 0x88EF;
pub const FLOAT_MAT2x3 = 0x8B65;
pub const FLOAT_MAT2x4 = 0x8B66;
pub const FLOAT_MAT3x2 = 0x8B67;
pub const FLOAT_MAT3x4 = 0x8B68;
pub const FLOAT_MAT4x2 = 0x8B69;
pub const FLOAT_MAT4x3 = 0x8B6A;
pub const SRGB = 0x8C40;
pub const SRGB8 = 0x8C41;
pub const SRGB_ALPHA = 0x8C42;
pub const SRGB8_ALPHA8 = 0x8C43;
pub const COMPRESSED_SRGB = 0x8C48;
pub const COMPRESSED_SRGB_ALPHA = 0x8C49;
pub const GEOMETRY_INPUT_TYPE = 0x8917;
pub const GEOMETRY_VERTICES_OUT = 0x8916;
pub const GEOMETRY_SHADER = 0x8DD9;
pub const FRAMEBUFFER_INCOMPLETE_LAYER_TARGETS = 0x8DA8;
pub const FRAMEBUFFER_ATTACHMENT_LAYERED = 0x8DA7;
pub const MAX_GEOMETRY_TEXTURE_IMAGE_UNITS = 0x8C29;
pub const PROGRAM_POINT_SIZE = 0x8642;
pub const COMPARE_REF_TO_TEXTURE = 0x884E;
pub const CLIP_DISTANCE0 = 0x3000;
pub const CLIP_DISTANCE1 = 0x3001;
pub const CLIP_DISTANCE2 = 0x3002;
pub const CLIP_DISTANCE3 = 0x3003;
pub const CLIP_DISTANCE4 = 0x3004;
pub const CLIP_DISTANCE5 = 0x3005;
pub const CLIP_DISTANCE6 = 0x3006;
pub const CLIP_DISTANCE7 = 0x3007;
pub const MAX_CLIP_DISTANCES = 0x0D32;
pub const MAJOR_VERSION = 0x821B;
pub const MINOR_VERSION = 0x821C;
pub const NUM_EXTENSIONS = 0x821D;
pub const CONTEXT_FLAGS = 0x821E;
pub const COMPRESSED_RED = 0x8225;
pub const COMPRESSED_RG = 0x8226;
pub const CONTEXT_FLAG_FORWARD_COMPATIBLE_BIT = 0x00000001;
pub const RGBA32F = 0x8814;
pub const RGB32F = 0x8815;
pub const RGBA16F = 0x881A;
pub const RGB16F = 0x881B;
pub const VERTEX_ATTRIB_ARRAY_INTEGER = 0x88FD;
pub const MAX_ARRAY_TEXTURE_LAYERS = 0x88FF;
pub const MIN_PROGRAM_TEXEL_OFFSET = 0x8904;
pub const MAX_PROGRAM_TEXEL_OFFSET = 0x8905;
pub const CLAMP_READ_COLOR = 0x891C;
pub const FIXED_ONLY = 0x891D;
pub const MAX_VARYING_COMPONENTS = 0x8B4B;
pub const TEXTURE_1D_ARRAY = 0x8C18;
pub const PROXY_TEXTURE_1D_ARRAY = 0x8C19;
pub const TEXTURE_2D_ARRAY = 0x8C1A;
pub const PROXY_TEXTURE_2D_ARRAY = 0x8C1B;
pub const TEXTURE_BINDING_1D_ARRAY = 0x8C1C;
pub const TEXTURE_BINDING_2D_ARRAY = 0x8C1D;
pub const R11F_G11F_B10F = 0x8C3A;
pub const UNSIGNED_INT_10F_11F_11F_REV = 0x8C3B;
pub const RGB9_E5 = 0x8C3D;
pub const UNSIGNED_INT_5_9_9_9_REV = 0x8C3E;
pub const TEXTURE_SHARED_SIZE = 0x8C3F;
pub const TRANSFORM_FEEDBACK_VARYING_MAX_LENGTH = 0x8C76;
pub const TRANSFORM_FEEDBACK_BUFFER_MODE = 0x8C7F;
pub const MAX_TRANSFORM_FEEDBACK_SEPARATE_COMPONENTS = 0x8C80;
pub const TRANSFORM_FEEDBACK_VARYINGS = 0x8C83;
pub const TRANSFORM_FEEDBACK_BUFFER_START = 0x8C84;
pub const TRANSFORM_FEEDBACK_BUFFER_SIZE = 0x8C85;
pub const PRIMITIVES_GENERATED = 0x8C87;
pub const TRANSFORM_FEEDBACK_PRIMITIVES_WRITTEN = 0x8C88;
pub const RASTERIZER_DISCARD = 0x8C89;
pub const MAX_TRANSFORM_FEEDBACK_INTERLEAVED_COMPONENTS = 0x8C8A;
pub const MAX_TRANSFORM_FEEDBACK_SEPARATE_ATTRIBS = 0x8C8B;
pub const INTERLEAVED_ATTRIBS = 0x8C8C;
pub const SEPARATE_ATTRIBS = 0x8C8D;
pub const TRANSFORM_FEEDBACK_BUFFER = 0x8C8E;
pub const TRANSFORM_FEEDBACK_BUFFER_BINDING = 0x8C8F;
pub const RGBA32UI = 0x8D70;
pub const RGB32UI = 0x8D71;
pub const RGBA16UI = 0x8D76;
pub const RGB16UI = 0x8D77;
pub const RGBA8UI = 0x8D7C;
pub const RGB8UI = 0x8D7D;
pub const RGBA32I = 0x8D82;
pub const RGB32I = 0x8D83;
pub const RGBA16I = 0x8D88;
pub const RGB16I = 0x8D89;
pub const RGBA8I = 0x8D8E;
pub const RGB8I = 0x8D8F;
pub const RED_INTEGER = 0x8D94;
pub const GREEN_INTEGER = 0x8D95;
pub const BLUE_INTEGER = 0x8D96;
pub const RGB_INTEGER = 0x8D98;
pub const RGBA_INTEGER = 0x8D99;
pub const BGR_INTEGER = 0x8D9A;
pub const BGRA_INTEGER = 0x8D9B;
pub const SAMPLER_1D_ARRAY = 0x8DC0;
pub const SAMPLER_2D_ARRAY = 0x8DC1;
pub const SAMPLER_1D_ARRAY_SHADOW = 0x8DC3;
pub const SAMPLER_2D_ARRAY_SHADOW = 0x8DC4;
pub const SAMPLER_CUBE_SHADOW = 0x8DC5;
pub const UNSIGNED_INT_VEC2 = 0x8DC6;
pub const UNSIGNED_INT_VEC3 = 0x8DC7;
pub const UNSIGNED_INT_VEC4 = 0x8DC8;
pub const INT_SAMPLER_1D = 0x8DC9;
pub const INT_SAMPLER_2D = 0x8DCA;
pub const INT_SAMPLER_3D = 0x8DCB;
pub const INT_SAMPLER_CUBE = 0x8DCC;
pub const INT_SAMPLER_1D_ARRAY = 0x8DCE;
pub const INT_SAMPLER_2D_ARRAY = 0x8DCF;
pub const UNSIGNED_INT_SAMPLER_1D = 0x8DD1;
pub const UNSIGNED_INT_SAMPLER_2D = 0x8DD2;
pub const UNSIGNED_INT_SAMPLER_3D = 0x8DD3;
pub const UNSIGNED_INT_SAMPLER_CUBE = 0x8DD4;
pub const UNSIGNED_INT_SAMPLER_1D_ARRAY = 0x8DD6;
pub const UNSIGNED_INT_SAMPLER_2D_ARRAY = 0x8DD7;
pub const QUERY_WAIT = 0x8E13;
pub const QUERY_NO_WAIT = 0x8E14;
pub const QUERY_BY_REGION_WAIT = 0x8E15;
pub const QUERY_BY_REGION_NO_WAIT = 0x8E16;
pub const BUFFER_ACCESS_FLAGS = 0x911F;
pub const BUFFER_MAP_LENGTH = 0x9120;
pub const BUFFER_MAP_OFFSET = 0x9121;
pub const DEPTH_COMPONENT32F = 0x8CAC;
pub const DEPTH32F_STENCIL8 = 0x8CAD;
pub const FLOAT_32_UNSIGNED_INT_24_8_REV = 0x8DAD;
pub const INVALID_FRAMEBUFFER_OPERATION = 0x0506;
pub const FRAMEBUFFER_ATTACHMENT_COLOR_ENCODING = 0x8210;
pub const FRAMEBUFFER_ATTACHMENT_COMPONENT_TYPE = 0x8211;
pub const FRAMEBUFFER_ATTACHMENT_RED_SIZE = 0x8212;
pub const FRAMEBUFFER_ATTACHMENT_GREEN_SIZE = 0x8213;
pub const FRAMEBUFFER_ATTACHMENT_BLUE_SIZE = 0x8214;
pub const FRAMEBUFFER_ATTACHMENT_ALPHA_SIZE = 0x8215;
pub const FRAMEBUFFER_ATTACHMENT_DEPTH_SIZE = 0x8216;
pub const FRAMEBUFFER_ATTACHMENT_STENCIL_SIZE = 0x8217;
pub const FRAMEBUFFER_DEFAULT = 0x8218;
pub const FRAMEBUFFER_UNDEFINED = 0x8219;
pub const DEPTH_STENCIL_ATTACHMENT = 0x821A;
pub const MAX_RENDERBUFFER_SIZE = 0x84E8;
pub const DEPTH_STENCIL = 0x84F9;
pub const UNSIGNED_INT_24_8 = 0x84FA;
pub const DEPTH24_STENCIL8 = 0x88F0;
pub const TEXTURE_STENCIL_SIZE = 0x88F1;
pub const TEXTURE_RED_TYPE = 0x8C10;
pub const TEXTURE_GREEN_TYPE = 0x8C11;
pub const TEXTURE_BLUE_TYPE = 0x8C12;
pub const TEXTURE_ALPHA_TYPE = 0x8C13;
pub const TEXTURE_DEPTH_TYPE = 0x8C16;
pub const UNSIGNED_NORMALIZED = 0x8C17;
pub const FRAMEBUFFER_BINDING = 0x8CA6;
pub const DRAW_FRAMEBUFFER_BINDING = 0x8CA6;
pub const RENDERBUFFER_BINDING = 0x8CA7;
pub const READ_FRAMEBUFFER = 0x8CA8;
pub const DRAW_FRAMEBUFFER = 0x8CA9;
pub const READ_FRAMEBUFFER_BINDING = 0x8CAA;
pub const RENDERBUFFER_SAMPLES = 0x8CAB;
pub const FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE = 0x8CD0;
pub const FRAMEBUFFER_ATTACHMENT_OBJECT_NAME = 0x8CD1;
pub const FRAMEBUFFER_ATTACHMENT_TEXTURE_LEVEL = 0x8CD2;
pub const FRAMEBUFFER_ATTACHMENT_TEXTURE_CUBE_MAP_FACE = 0x8CD3;
pub const FRAMEBUFFER_ATTACHMENT_TEXTURE_LAYER = 0x8CD4;
pub const FRAMEBUFFER_COMPLETE = 0x8CD5;
pub const FRAMEBUFFER_INCOMPLETE_ATTACHMENT = 0x8CD6;
pub const FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT = 0x8CD7;
pub const FRAMEBUFFER_INCOMPLETE_DRAW_BUFFER = 0x8CDB;
pub const FRAMEBUFFER_INCOMPLETE_READ_BUFFER = 0x8CDC;
pub const FRAMEBUFFER_UNSUPPORTED = 0x8CDD;
pub const MAX_COLOR_ATTACHMENTS = 0x8CDF;
pub const COLOR_ATTACHMENT0 = 0x8CE0;
pub const COLOR_ATTACHMENT1 = 0x8CE1;
pub const COLOR_ATTACHMENT2 = 0x8CE2;
pub const COLOR_ATTACHMENT3 = 0x8CE3;
pub const COLOR_ATTACHMENT4 = 0x8CE4;
pub const COLOR_ATTACHMENT5 = 0x8CE5;
pub const COLOR_ATTACHMENT6 = 0x8CE6;
pub const COLOR_ATTACHMENT7 = 0x8CE7;
pub const COLOR_ATTACHMENT8 = 0x8CE8;
pub const COLOR_ATTACHMENT9 = 0x8CE9;
pub const COLOR_ATTACHMENT10 = 0x8CEA;
pub const COLOR_ATTACHMENT11 = 0x8CEB;
pub const COLOR_ATTACHMENT12 = 0x8CEC;
pub const COLOR_ATTACHMENT13 = 0x8CED;
pub const COLOR_ATTACHMENT14 = 0x8CEE;
pub const COLOR_ATTACHMENT15 = 0x8CEF;
pub const COLOR_ATTACHMENT16 = 0x8CF0;
pub const COLOR_ATTACHMENT17 = 0x8CF1;
pub const COLOR_ATTACHMENT18 = 0x8CF2;
pub const COLOR_ATTACHMENT19 = 0x8CF3;
pub const COLOR_ATTACHMENT20 = 0x8CF4;
pub const COLOR_ATTACHMENT21 = 0x8CF5;
pub const COLOR_ATTACHMENT22 = 0x8CF6;
pub const COLOR_ATTACHMENT23 = 0x8CF7;
pub const COLOR_ATTACHMENT24 = 0x8CF8;
pub const COLOR_ATTACHMENT25 = 0x8CF9;
pub const COLOR_ATTACHMENT26 = 0x8CFA;
pub const COLOR_ATTACHMENT27 = 0x8CFB;
pub const COLOR_ATTACHMENT28 = 0x8CFC;
pub const COLOR_ATTACHMENT29 = 0x8CFD;
pub const COLOR_ATTACHMENT30 = 0x8CFE;
pub const COLOR_ATTACHMENT31 = 0x8CFF;
pub const DEPTH_ATTACHMENT = 0x8D00;
pub const STENCIL_ATTACHMENT = 0x8D20;
pub const FRAMEBUFFER = 0x8D40;
pub const RENDERBUFFER = 0x8D41;
pub const RENDERBUFFER_WIDTH = 0x8D42;
pub const RENDERBUFFER_HEIGHT = 0x8D43;
pub const RENDERBUFFER_INTERNAL_FORMAT = 0x8D44;
pub const STENCIL_INDEX1 = 0x8D46;
pub const STENCIL_INDEX4 = 0x8D47;
pub const STENCIL_INDEX8 = 0x8D48;
pub const STENCIL_INDEX16 = 0x8D49;
pub const RENDERBUFFER_RED_SIZE = 0x8D50;
pub const RENDERBUFFER_GREEN_SIZE = 0x8D51;
pub const RENDERBUFFER_BLUE_SIZE = 0x8D52;
pub const RENDERBUFFER_ALPHA_SIZE = 0x8D53;
pub const RENDERBUFFER_DEPTH_SIZE = 0x8D54;
pub const RENDERBUFFER_STENCIL_SIZE = 0x8D55;
pub const FRAMEBUFFER_INCOMPLETE_MULTISAMPLE = 0x8D56;
pub const MAX_SAMPLES = 0x8D57;
pub const LINES_ADJACENCY = 0x000A;
pub const CONTEXT_COMPATIBILITY_PROFILE_BIT = 0x00000002;
pub const CONTEXT_CORE_PROFILE_BIT = 0x00000001;
pub const FRAMEBUFFER_SRGB = 0x8DB9;
pub const HALF_FLOAT = 0x140B;
pub const MAP_READ_BIT = 0x0001;
pub const MAP_WRITE_BIT = 0x0002;
pub const MAP_INVALIDATE_RANGE_BIT = 0x0004;
pub const MAP_INVALIDATE_BUFFER_BIT = 0x0008;
pub const MAP_FLUSH_EXPLICIT_BIT = 0x0010;
pub const MAP_UNSYNCHRONIZED_BIT = 0x0020;
pub const COMPRESSED_RED_RGTC1 = 0x8DBB;
pub const COMPRESSED_SIGNED_RED_RGTC1 = 0x8DBC;
pub const COMPRESSED_RG_RGTC2 = 0x8DBD;
pub const COMPRESSED_SIGNED_RG_RGTC2 = 0x8DBE;
pub const RG = 0x8227;
pub const RG_INTEGER = 0x8228;
pub const R8 = 0x8229;
pub const R16 = 0x822A;
pub const RG8 = 0x822B;
pub const RG16 = 0x822C;
pub const R16F = 0x822D;
pub const R32F = 0x822E;
pub const RG16F = 0x822F;
pub const RG32F = 0x8230;
pub const R8I = 0x8231;
pub const R8UI = 0x8232;
pub const R16I = 0x8233;
pub const R16UI = 0x8234;
pub const R32I = 0x8235;
pub const R32UI = 0x8236;
pub const RG8I = 0x8237;
pub const RG8UI = 0x8238;
pub const RG16I = 0x8239;
pub const RG16UI = 0x823A;
pub const RG32I = 0x823B;
pub const RG32UI = 0x823C;
pub const VERTEX_ARRAY_BINDING = 0x85B5;
pub const TRIANGLE_STRIP_ADJACENCY = 0x000D;
pub const TRIANGLES_ADJACENCY = 0x000C;
pub const LINE_STRIP_ADJACENCY = 0x000B;
pub const SAMPLER_2D_RECT = 0x8B63;
pub const SAMPLER_2D_RECT_SHADOW = 0x8B64;
pub const SAMPLER_BUFFER = 0x8DC2;
pub const INT_SAMPLER_2D_RECT = 0x8DCD;
pub const INT_SAMPLER_BUFFER = 0x8DD0;
pub const UNSIGNED_INT_SAMPLER_2D_RECT = 0x8DD5;
pub const UNSIGNED_INT_SAMPLER_BUFFER = 0x8DD8;
pub const TEXTURE_BUFFER = 0x8C2A;
pub const MAX_TEXTURE_BUFFER_SIZE = 0x8C2B;
pub const TEXTURE_BINDING_BUFFER = 0x8C2C;
pub const TEXTURE_BUFFER_DATA_STORE_BINDING = 0x8C2D;
pub const TEXTURE_RECTANGLE = 0x84F5;
pub const TEXTURE_BINDING_RECTANGLE = 0x84F6;
pub const PROXY_TEXTURE_RECTANGLE = 0x84F7;
pub const MAX_RECTANGLE_TEXTURE_SIZE = 0x84F8;
pub const R8_SNORM = 0x8F94;
pub const RG8_SNORM = 0x8F95;
pub const RGB8_SNORM = 0x8F96;
pub const RGBA8_SNORM = 0x8F97;
pub const R16_SNORM = 0x8F98;
pub const RG16_SNORM = 0x8F99;
pub const RGB16_SNORM = 0x8F9A;
pub const RGBA16_SNORM = 0x8F9B;
pub const SIGNED_NORMALIZED = 0x8F9C;
pub const PRIMITIVE_RESTART = 0x8F9D;
pub const PRIMITIVE_RESTART_INDEX = 0x8F9E;
pub const COPY_READ_BUFFER = 0x8F36;
pub const COPY_WRITE_BUFFER = 0x8F37;
pub const UNIFORM_BUFFER = 0x8A11;
pub const UNIFORM_BUFFER_BINDING = 0x8A28;
pub const UNIFORM_BUFFER_START = 0x8A29;
pub const UNIFORM_BUFFER_SIZE = 0x8A2A;
pub const MAX_VERTEX_UNIFORM_BLOCKS = 0x8A2B;
pub const MAX_GEOMETRY_UNIFORM_BLOCKS = 0x8A2C;
pub const MAX_FRAGMENT_UNIFORM_BLOCKS = 0x8A2D;
pub const MAX_COMBINED_UNIFORM_BLOCKS = 0x8A2E;
pub const MAX_UNIFORM_BUFFER_BINDINGS = 0x8A2F;
pub const MAX_UNIFORM_BLOCK_SIZE = 0x8A30;
pub const MAX_COMBINED_VERTEX_UNIFORM_COMPONENTS = 0x8A31;
pub const MAX_COMBINED_GEOMETRY_UNIFORM_COMPONENTS = 0x8A32;
pub const MAX_COMBINED_FRAGMENT_UNIFORM_COMPONENTS = 0x8A33;
pub const UNIFORM_BUFFER_OFFSET_ALIGNMENT = 0x8A34;
pub const ACTIVE_UNIFORM_BLOCK_MAX_NAME_LENGTH = 0x8A35;
pub const ACTIVE_UNIFORM_BLOCKS = 0x8A36;
pub const UNIFORM_TYPE = 0x8A37;
pub const UNIFORM_SIZE = 0x8A38;
pub const UNIFORM_NAME_LENGTH = 0x8A39;
pub const UNIFORM_BLOCK_INDEX = 0x8A3A;
pub const UNIFORM_OFFSET = 0x8A3B;
pub const UNIFORM_ARRAY_STRIDE = 0x8A3C;
pub const UNIFORM_MATRIX_STRIDE = 0x8A3D;
pub const UNIFORM_IS_ROW_MAJOR = 0x8A3E;
pub const UNIFORM_BLOCK_BINDING = 0x8A3F;
pub const UNIFORM_BLOCK_DATA_SIZE = 0x8A40;
pub const UNIFORM_BLOCK_NAME_LENGTH = 0x8A41;
pub const UNIFORM_BLOCK_ACTIVE_UNIFORMS = 0x8A42;
pub const UNIFORM_BLOCK_ACTIVE_UNIFORM_INDICES = 0x8A43;
pub const UNIFORM_BLOCK_REFERENCED_BY_VERTEX_SHADER = 0x8A44;
pub const UNIFORM_BLOCK_REFERENCED_BY_GEOMETRY_SHADER = 0x8A45;
pub const UNIFORM_BLOCK_REFERENCED_BY_FRAGMENT_SHADER = 0x8A46;
pub const INVALID_INDEX = 0xFFFFFFFF;

pub fn cullFace(_mode: GLenum) callconv(.C) void {
    return @call(.always_tail, function_pointers.glCullFace, .{_mode});
}

pub fn frontFace(_mode: GLenum) callconv(.C) void {
    return @call(.always_tail, function_pointers.glFrontFace, .{_mode});
}

pub fn hint(_target: GLenum, _mode: GLenum) callconv(.C) void {
    return @call(.always_tail, function_pointers.glHint, .{ _target, _mode });
}

pub fn lineWidth(_width: GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glLineWidth, .{_width});
}

pub fn pointSize(_size: GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glPointSize, .{_size});
}

pub fn polygonMode(_face: GLenum, _mode: GLenum) callconv(.C) void {
    return @call(.always_tail, function_pointers.glPolygonMode, .{ _face, _mode });
}

pub fn scissor(_x: GLint, _y: GLint, _width: GLsizei, _height: GLsizei) callconv(.C) void {
    return @call(.always_tail, function_pointers.glScissor, .{ _x, _y, _width, _height });
}

pub fn texParameterf(_target: GLenum, _pname: GLenum, _param: GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glTexParameterf, .{ _target, _pname, _param });
}

pub fn texParameterfv(_target: GLenum, _pname: GLenum, _params: [*c]const GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glTexParameterfv, .{ _target, _pname, _params });
}

pub fn texParameteri(_target: GLenum, _pname: GLenum, _param: GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glTexParameteri, .{ _target, _pname, _param });
}

pub fn texParameteriv(_target: GLenum, _pname: GLenum, _params: [*c]const GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glTexParameteriv, .{ _target, _pname, _params });
}

pub fn texImage1D(_target: GLenum, _level: GLint, _internalformat: GLint, _width: GLsizei, _border: GLint, _format: GLenum, _type: GLenum, _pixels: ?*const anyopaque) callconv(.C) void {
    return @call(.always_tail, function_pointers.glTexImage1D, .{ _target, _level, _internalformat, _width, _border, _format, _type, _pixels });
}

pub fn texImage2D(_target: GLenum, _level: GLint, _internalformat: GLint, _width: GLsizei, _height: GLsizei, _border: GLint, _format: GLenum, _type: GLenum, _pixels: ?*const anyopaque) callconv(.C) void {
    return @call(.always_tail, function_pointers.glTexImage2D, .{ _target, _level, _internalformat, _width, _height, _border, _format, _type, _pixels });
}

pub fn drawBuffer(_buf: GLenum) callconv(.C) void {
    return @call(.always_tail, function_pointers.glDrawBuffer, .{_buf});
}

pub fn clear(_mask: GLbitfield) callconv(.C) void {
    return @call(.always_tail, function_pointers.glClear, .{_mask});
}

pub fn clearColor(_red: GLfloat, _green: GLfloat, _blue: GLfloat, _alpha: GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glClearColor, .{ _red, _green, _blue, _alpha });
}

pub fn clearStencil(_s: GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glClearStencil, .{_s});
}

pub fn clearDepth(_depth: GLdouble) callconv(.C) void {
    return @call(.always_tail, function_pointers.glClearDepth, .{_depth});
}

pub fn stencilMask(_mask: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glStencilMask, .{_mask});
}

pub fn colorMask(_red: GLboolean, _green: GLboolean, _blue: GLboolean, _alpha: GLboolean) callconv(.C) void {
    return @call(.always_tail, function_pointers.glColorMask, .{ _red, _green, _blue, _alpha });
}

pub fn depthMask(_flag: GLboolean) callconv(.C) void {
    return @call(.always_tail, function_pointers.glDepthMask, .{_flag});
}

pub fn disable(_cap: GLenum) callconv(.C) void {
    return @call(.always_tail, function_pointers.glDisable, .{_cap});
}

pub fn enable(_cap: GLenum) callconv(.C) void {
    return @call(.always_tail, function_pointers.glEnable, .{_cap});
}

pub fn finish() callconv(.C) void {
    return @call(.always_tail, function_pointers.glFinish, .{});
}

pub fn flush() callconv(.C) void {
    return @call(.always_tail, function_pointers.glFlush, .{});
}

pub fn blendFunc(_sfactor: GLenum, _dfactor: GLenum) callconv(.C) void {
    return @call(.always_tail, function_pointers.glBlendFunc, .{ _sfactor, _dfactor });
}

pub fn logicOp(_opcode: GLenum) callconv(.C) void {
    return @call(.always_tail, function_pointers.glLogicOp, .{_opcode});
}

pub fn stencilFunc(_func: GLenum, _ref: GLint, _mask: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glStencilFunc, .{ _func, _ref, _mask });
}

pub fn stencilOp(_fail: GLenum, _zfail: GLenum, _zpass: GLenum) callconv(.C) void {
    return @call(.always_tail, function_pointers.glStencilOp, .{ _fail, _zfail, _zpass });
}

pub fn depthFunc(_func: GLenum) callconv(.C) void {
    return @call(.always_tail, function_pointers.glDepthFunc, .{_func});
}

pub fn pixelStoref(_pname: GLenum, _param: GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glPixelStoref, .{ _pname, _param });
}

pub fn pixelStorei(_pname: GLenum, _param: GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glPixelStorei, .{ _pname, _param });
}

pub fn readBuffer(_src: GLenum) callconv(.C) void {
    return @call(.always_tail, function_pointers.glReadBuffer, .{_src});
}

pub fn readPixels(_x: GLint, _y: GLint, _width: GLsizei, _height: GLsizei, _format: GLenum, _type: GLenum, _pixels: ?*anyopaque) callconv(.C) void {
    return @call(.always_tail, function_pointers.glReadPixels, .{ _x, _y, _width, _height, _format, _type, _pixels });
}

pub fn getBooleanv(_pname: GLenum, _data: [*c]GLboolean) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetBooleanv, .{ _pname, _data });
}

pub fn getDoublev(_pname: GLenum, _data: [*c]GLdouble) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetDoublev, .{ _pname, _data });
}

pub fn getError() callconv(.C) GLenum {
    return @call(.always_tail, function_pointers.glGetError, .{});
}

pub fn getFloatv(_pname: GLenum, _data: [*c]GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetFloatv, .{ _pname, _data });
}

pub fn getIntegerv(_pname: GLenum, _data: [*c]GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetIntegerv, .{ _pname, _data });
}

pub fn getString(_name: GLenum) callconv(.C) ?[*:0]const GLubyte {
    return @call(.always_tail, function_pointers.glGetString, .{_name});
}

pub fn getTexImage(_target: GLenum, _level: GLint, _format: GLenum, _type: GLenum, _pixels: ?*anyopaque) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetTexImage, .{ _target, _level, _format, _type, _pixels });
}

pub fn getTexParameterfv(_target: GLenum, _pname: GLenum, _params: [*c]GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetTexParameterfv, .{ _target, _pname, _params });
}

pub fn getTexParameteriv(_target: GLenum, _pname: GLenum, _params: [*c]GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetTexParameteriv, .{ _target, _pname, _params });
}

pub fn getTexLevelParameterfv(_target: GLenum, _level: GLint, _pname: GLenum, _params: [*c]GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetTexLevelParameterfv, .{ _target, _level, _pname, _params });
}

pub fn getTexLevelParameteriv(_target: GLenum, _level: GLint, _pname: GLenum, _params: [*c]GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetTexLevelParameteriv, .{ _target, _level, _pname, _params });
}

pub fn isEnabled(_cap: GLenum) callconv(.C) GLboolean {
    return @call(.always_tail, function_pointers.glIsEnabled, .{_cap});
}

pub fn depthRange(_n: GLdouble, _f: GLdouble) callconv(.C) void {
    return @call(.always_tail, function_pointers.glDepthRange, .{ _n, _f });
}

pub fn viewport(_x: GLint, _y: GLint, _width: GLsizei, _height: GLsizei) callconv(.C) void {
    return @call(.always_tail, function_pointers.glViewport, .{ _x, _y, _width, _height });
}

pub fn drawArrays(_mode: GLenum, _first: GLint, _count: GLsizei) callconv(.C) void {
    return @call(.always_tail, function_pointers.glDrawArrays, .{ _mode, _first, _count });
}

pub fn drawElements(_mode: GLenum, _count: GLsizei, _type: GLenum, _indices: ?*const anyopaque) callconv(.C) void {
    return @call(.always_tail, function_pointers.glDrawElements, .{ _mode, _count, _type, _indices });
}

pub fn polygonOffset(_factor: GLfloat, _units: GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glPolygonOffset, .{ _factor, _units });
}

pub fn copyTexImage1D(_target: GLenum, _level: GLint, _internalformat: GLenum, _x: GLint, _y: GLint, _width: GLsizei, _border: GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glCopyTexImage1D, .{ _target, _level, _internalformat, _x, _y, _width, _border });
}

pub fn copyTexImage2D(_target: GLenum, _level: GLint, _internalformat: GLenum, _x: GLint, _y: GLint, _width: GLsizei, _height: GLsizei, _border: GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glCopyTexImage2D, .{ _target, _level, _internalformat, _x, _y, _width, _height, _border });
}

pub fn copyTexSubImage1D(_target: GLenum, _level: GLint, _xoffset: GLint, _x: GLint, _y: GLint, _width: GLsizei) callconv(.C) void {
    return @call(.always_tail, function_pointers.glCopyTexSubImage1D, .{ _target, _level, _xoffset, _x, _y, _width });
}

pub fn copyTexSubImage2D(_target: GLenum, _level: GLint, _xoffset: GLint, _yoffset: GLint, _x: GLint, _y: GLint, _width: GLsizei, _height: GLsizei) callconv(.C) void {
    return @call(.always_tail, function_pointers.glCopyTexSubImage2D, .{ _target, _level, _xoffset, _yoffset, _x, _y, _width, _height });
}

pub fn texSubImage1D(_target: GLenum, _level: GLint, _xoffset: GLint, _width: GLsizei, _format: GLenum, _type: GLenum, _pixels: ?*const anyopaque) callconv(.C) void {
    return @call(.always_tail, function_pointers.glTexSubImage1D, .{ _target, _level, _xoffset, _width, _format, _type, _pixels });
}

pub fn texSubImage2D(_target: GLenum, _level: GLint, _xoffset: GLint, _yoffset: GLint, _width: GLsizei, _height: GLsizei, _format: GLenum, _type: GLenum, _pixels: ?*const anyopaque) callconv(.C) void {
    return @call(.always_tail, function_pointers.glTexSubImage2D, .{ _target, _level, _xoffset, _yoffset, _width, _height, _format, _type, _pixels });
}

pub fn bindTexture(_target: GLenum, _texture: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glBindTexture, .{ _target, _texture });
}

pub fn deleteTextures(_n: GLsizei, _textures: [*c]const GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glDeleteTextures, .{ _n, _textures });
}

pub fn genTextures(_n: GLsizei, _textures: [*c]GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGenTextures, .{ _n, _textures });
}

pub fn isTexture(_texture: GLuint) callconv(.C) GLboolean {
    return @call(.always_tail, function_pointers.glIsTexture, .{_texture});
}

pub fn drawRangeElements(_mode: GLenum, _start: GLuint, _end: GLuint, _count: GLsizei, _type: GLenum, _indices: ?*const anyopaque) callconv(.C) void {
    return @call(.always_tail, function_pointers.glDrawRangeElements, .{ _mode, _start, _end, _count, _type, _indices });
}

pub fn texImage3D(_target: GLenum, _level: GLint, _internalformat: GLint, _width: GLsizei, _height: GLsizei, _depth: GLsizei, _border: GLint, _format: GLenum, _type: GLenum, _pixels: ?*const anyopaque) callconv(.C) void {
    return @call(.always_tail, function_pointers.glTexImage3D, .{ _target, _level, _internalformat, _width, _height, _depth, _border, _format, _type, _pixels });
}

pub fn texSubImage3D(_target: GLenum, _level: GLint, _xoffset: GLint, _yoffset: GLint, _zoffset: GLint, _width: GLsizei, _height: GLsizei, _depth: GLsizei, _format: GLenum, _type: GLenum, _pixels: ?*const anyopaque) callconv(.C) void {
    return @call(.always_tail, function_pointers.glTexSubImage3D, .{ _target, _level, _xoffset, _yoffset, _zoffset, _width, _height, _depth, _format, _type, _pixels });
}

pub fn copyTexSubImage3D(_target: GLenum, _level: GLint, _xoffset: GLint, _yoffset: GLint, _zoffset: GLint, _x: GLint, _y: GLint, _width: GLsizei, _height: GLsizei) callconv(.C) void {
    return @call(.always_tail, function_pointers.glCopyTexSubImage3D, .{ _target, _level, _xoffset, _yoffset, _zoffset, _x, _y, _width, _height });
}

pub fn activeTexture(_texture: GLenum) callconv(.C) void {
    return @call(.always_tail, function_pointers.glActiveTexture, .{_texture});
}

pub fn sampleCoverage(_value: GLfloat, _invert: GLboolean) callconv(.C) void {
    return @call(.always_tail, function_pointers.glSampleCoverage, .{ _value, _invert });
}

pub fn compressedTexImage3D(_target: GLenum, _level: GLint, _internalformat: GLenum, _width: GLsizei, _height: GLsizei, _depth: GLsizei, _border: GLint, _imageSize: GLsizei, _data: ?*const anyopaque) callconv(.C) void {
    return @call(.always_tail, function_pointers.glCompressedTexImage3D, .{ _target, _level, _internalformat, _width, _height, _depth, _border, _imageSize, _data });
}

pub fn compressedTexImage2D(_target: GLenum, _level: GLint, _internalformat: GLenum, _width: GLsizei, _height: GLsizei, _border: GLint, _imageSize: GLsizei, _data: ?*const anyopaque) callconv(.C) void {
    return @call(.always_tail, function_pointers.glCompressedTexImage2D, .{ _target, _level, _internalformat, _width, _height, _border, _imageSize, _data });
}

pub fn compressedTexImage1D(_target: GLenum, _level: GLint, _internalformat: GLenum, _width: GLsizei, _border: GLint, _imageSize: GLsizei, _data: ?*const anyopaque) callconv(.C) void {
    return @call(.always_tail, function_pointers.glCompressedTexImage1D, .{ _target, _level, _internalformat, _width, _border, _imageSize, _data });
}

pub fn compressedTexSubImage3D(_target: GLenum, _level: GLint, _xoffset: GLint, _yoffset: GLint, _zoffset: GLint, _width: GLsizei, _height: GLsizei, _depth: GLsizei, _format: GLenum, _imageSize: GLsizei, _data: ?*const anyopaque) callconv(.C) void {
    return @call(.always_tail, function_pointers.glCompressedTexSubImage3D, .{ _target, _level, _xoffset, _yoffset, _zoffset, _width, _height, _depth, _format, _imageSize, _data });
}

pub fn compressedTexSubImage2D(_target: GLenum, _level: GLint, _xoffset: GLint, _yoffset: GLint, _width: GLsizei, _height: GLsizei, _format: GLenum, _imageSize: GLsizei, _data: ?*const anyopaque) callconv(.C) void {
    return @call(.always_tail, function_pointers.glCompressedTexSubImage2D, .{ _target, _level, _xoffset, _yoffset, _width, _height, _format, _imageSize, _data });
}

pub fn compressedTexSubImage1D(_target: GLenum, _level: GLint, _xoffset: GLint, _width: GLsizei, _format: GLenum, _imageSize: GLsizei, _data: ?*const anyopaque) callconv(.C) void {
    return @call(.always_tail, function_pointers.glCompressedTexSubImage1D, .{ _target, _level, _xoffset, _width, _format, _imageSize, _data });
}

pub fn getCompressedTexImage(_target: GLenum, _level: GLint, _img: ?*anyopaque) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetCompressedTexImage, .{ _target, _level, _img });
}

pub fn vertexAttribP4uiv(_index: GLuint, _type: GLenum, _normalized: GLboolean, _value: [*c]const GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttribP4uiv, .{ _index, _type, _normalized, _value });
}

pub fn vertexAttribP4ui(_index: GLuint, _type: GLenum, _normalized: GLboolean, _value: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttribP4ui, .{ _index, _type, _normalized, _value });
}

pub fn vertexAttribP3uiv(_index: GLuint, _type: GLenum, _normalized: GLboolean, _value: [*c]const GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttribP3uiv, .{ _index, _type, _normalized, _value });
}

pub fn vertexAttribP3ui(_index: GLuint, _type: GLenum, _normalized: GLboolean, _value: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttribP3ui, .{ _index, _type, _normalized, _value });
}

pub fn vertexAttribP2uiv(_index: GLuint, _type: GLenum, _normalized: GLboolean, _value: [*c]const GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttribP2uiv, .{ _index, _type, _normalized, _value });
}

pub fn vertexAttribP2ui(_index: GLuint, _type: GLenum, _normalized: GLboolean, _value: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttribP2ui, .{ _index, _type, _normalized, _value });
}

pub fn vertexAttribP1uiv(_index: GLuint, _type: GLenum, _normalized: GLboolean, _value: [*c]const GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttribP1uiv, .{ _index, _type, _normalized, _value });
}

pub fn vertexAttribP1ui(_index: GLuint, _type: GLenum, _normalized: GLboolean, _value: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttribP1ui, .{ _index, _type, _normalized, _value });
}

pub fn vertexAttribDivisor(_index: GLuint, _divisor: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttribDivisor, .{ _index, _divisor });
}

pub fn getQueryObjectui64v(_id: GLuint, _pname: GLenum, _params: [*c]GLuint64) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetQueryObjectui64v, .{ _id, _pname, _params });
}

pub fn getQueryObjecti64v(_id: GLuint, _pname: GLenum, _params: [*c]GLint64) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetQueryObjecti64v, .{ _id, _pname, _params });
}

pub fn queryCounter(_id: GLuint, _target: GLenum) callconv(.C) void {
    return @call(.always_tail, function_pointers.glQueryCounter, .{ _id, _target });
}

pub fn getSamplerParameterIuiv(_sampler: GLuint, _pname: GLenum, _params: [*c]GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetSamplerParameterIuiv, .{ _sampler, _pname, _params });
}

pub fn getSamplerParameterfv(_sampler: GLuint, _pname: GLenum, _params: [*c]GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetSamplerParameterfv, .{ _sampler, _pname, _params });
}

pub fn getSamplerParameterIiv(_sampler: GLuint, _pname: GLenum, _params: [*c]GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetSamplerParameterIiv, .{ _sampler, _pname, _params });
}

pub fn getSamplerParameteriv(_sampler: GLuint, _pname: GLenum, _params: [*c]GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetSamplerParameteriv, .{ _sampler, _pname, _params });
}

pub fn samplerParameterIuiv(_sampler: GLuint, _pname: GLenum, _param: [*c]const GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glSamplerParameterIuiv, .{ _sampler, _pname, _param });
}

pub fn samplerParameterIiv(_sampler: GLuint, _pname: GLenum, _param: [*c]const GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glSamplerParameterIiv, .{ _sampler, _pname, _param });
}

pub fn samplerParameterfv(_sampler: GLuint, _pname: GLenum, _param: [*c]const GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glSamplerParameterfv, .{ _sampler, _pname, _param });
}

pub fn samplerParameterf(_sampler: GLuint, _pname: GLenum, _param: GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glSamplerParameterf, .{ _sampler, _pname, _param });
}

pub fn samplerParameteriv(_sampler: GLuint, _pname: GLenum, _param: [*c]const GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glSamplerParameteriv, .{ _sampler, _pname, _param });
}

pub fn samplerParameteri(_sampler: GLuint, _pname: GLenum, _param: GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glSamplerParameteri, .{ _sampler, _pname, _param });
}

pub fn bindSampler(_unit: GLuint, _sampler: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glBindSampler, .{ _unit, _sampler });
}

pub fn isSampler(_sampler: GLuint) callconv(.C) GLboolean {
    return @call(.always_tail, function_pointers.glIsSampler, .{_sampler});
}

pub fn deleteSamplers(_count: GLsizei, _samplers: [*c]const GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glDeleteSamplers, .{ _count, _samplers });
}

pub fn genSamplers(_count: GLsizei, _samplers: [*c]GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGenSamplers, .{ _count, _samplers });
}

pub fn getFragDataIndex(_program: GLuint, _name: [*c]const GLchar) callconv(.C) GLint {
    return @call(.always_tail, function_pointers.glGetFragDataIndex, .{ _program, _name });
}

pub fn bindFragDataLocationIndexed(_program: GLuint, _colorNumber: GLuint, _index: GLuint, _name: [*c]const GLchar) callconv(.C) void {
    return @call(.always_tail, function_pointers.glBindFragDataLocationIndexed, .{ _program, _colorNumber, _index, _name });
}

pub fn sampleMaski(_maskNumber: GLuint, _mask: GLbitfield) callconv(.C) void {
    return @call(.always_tail, function_pointers.glSampleMaski, .{ _maskNumber, _mask });
}

pub fn getMultisamplefv(_pname: GLenum, _index: GLuint, _val: [*c]GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetMultisamplefv, .{ _pname, _index, _val });
}

pub fn texImage3DMultisample(_target: GLenum, _samples: GLsizei, _internalformat: GLenum, _width: GLsizei, _height: GLsizei, _depth: GLsizei, _fixedsamplelocations: GLboolean) callconv(.C) void {
    return @call(.always_tail, function_pointers.glTexImage3DMultisample, .{ _target, _samples, _internalformat, _width, _height, _depth, _fixedsamplelocations });
}

pub fn texImage2DMultisample(_target: GLenum, _samples: GLsizei, _internalformat: GLenum, _width: GLsizei, _height: GLsizei, _fixedsamplelocations: GLboolean) callconv(.C) void {
    return @call(.always_tail, function_pointers.glTexImage2DMultisample, .{ _target, _samples, _internalformat, _width, _height, _fixedsamplelocations });
}

pub fn framebufferTexture(_target: GLenum, _attachment: GLenum, _texture: GLuint, _level: GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glFramebufferTexture, .{ _target, _attachment, _texture, _level });
}

pub fn getBufferParameteri64v(_target: GLenum, _pname: GLenum, _params: [*c]GLint64) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetBufferParameteri64v, .{ _target, _pname, _params });
}

pub fn blendFuncSeparate(_sfactorRGB: GLenum, _dfactorRGB: GLenum, _sfactorAlpha: GLenum, _dfactorAlpha: GLenum) callconv(.C) void {
    return @call(.always_tail, function_pointers.glBlendFuncSeparate, .{ _sfactorRGB, _dfactorRGB, _sfactorAlpha, _dfactorAlpha });
}

pub fn multiDrawArrays(_mode: GLenum, _first: [*c]const GLint, _count: [*c]const GLsizei, _drawcount: GLsizei) callconv(.C) void {
    return @call(.always_tail, function_pointers.glMultiDrawArrays, .{ _mode, _first, _count, _drawcount });
}

pub fn multiDrawElements(_mode: GLenum, _count: [*c]const GLsizei, _type: GLenum, _indices: [*c]const ?*const anyopaque, _drawcount: GLsizei) callconv(.C) void {
    return @call(.always_tail, function_pointers.glMultiDrawElements, .{ _mode, _count, _type, _indices, _drawcount });
}

pub fn pointParameterf(_pname: GLenum, _param: GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glPointParameterf, .{ _pname, _param });
}

pub fn pointParameterfv(_pname: GLenum, _params: [*c]const GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glPointParameterfv, .{ _pname, _params });
}

pub fn pointParameteri(_pname: GLenum, _param: GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glPointParameteri, .{ _pname, _param });
}

pub fn pointParameteriv(_pname: GLenum, _params: [*c]const GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glPointParameteriv, .{ _pname, _params });
}

pub fn getInteger64i_v(_target: GLenum, _index: GLuint, _data: [*c]GLint64) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetInteger64i_v, .{ _target, _index, _data });
}

pub fn getSynciv(_sync: GLsync, _pname: GLenum, _count: GLsizei, _length: [*c]GLsizei, _values: [*c]GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetSynciv, .{ _sync, _pname, _count, _length, _values });
}

pub fn getInteger64v(_pname: GLenum, _data: [*c]GLint64) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetInteger64v, .{ _pname, _data });
}

pub fn waitSync(_sync: GLsync, _flags: GLbitfield, _timeout: GLuint64) callconv(.C) void {
    return @call(.always_tail, function_pointers.glWaitSync, .{ _sync, _flags, _timeout });
}

pub fn clientWaitSync(_sync: GLsync, _flags: GLbitfield, _timeout: GLuint64) callconv(.C) GLenum {
    return @call(.always_tail, function_pointers.glClientWaitSync, .{ _sync, _flags, _timeout });
}

pub fn deleteSync(_sync: GLsync) callconv(.C) void {
    return @call(.always_tail, function_pointers.glDeleteSync, .{_sync});
}

pub fn isSync(_sync: GLsync) callconv(.C) GLboolean {
    return @call(.always_tail, function_pointers.glIsSync, .{_sync});
}

pub fn fenceSync(_condition: GLenum, _flags: GLbitfield) callconv(.C) GLsync {
    return @call(.always_tail, function_pointers.glFenceSync, .{ _condition, _flags });
}

pub fn blendColor(_red: GLfloat, _green: GLfloat, _blue: GLfloat, _alpha: GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glBlendColor, .{ _red, _green, _blue, _alpha });
}

pub fn blendEquation(_mode: GLenum) callconv(.C) void {
    return @call(.always_tail, function_pointers.glBlendEquation, .{_mode});
}

pub fn provokingVertex(_mode: GLenum) callconv(.C) void {
    return @call(.always_tail, function_pointers.glProvokingVertex, .{_mode});
}

pub fn multiDrawElementsBaseVertex(_mode: GLenum, _count: [*c]const GLsizei, _type: GLenum, _indices: [*c]const ?*const anyopaque, _drawcount: GLsizei, _basevertex: [*c]const GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glMultiDrawElementsBaseVertex, .{ _mode, _count, _type, _indices, _drawcount, _basevertex });
}

pub fn drawElementsInstancedBaseVertex(_mode: GLenum, _count: GLsizei, _type: GLenum, _indices: ?*const anyopaque, _instancecount: GLsizei, _basevertex: GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glDrawElementsInstancedBaseVertex, .{ _mode, _count, _type, _indices, _instancecount, _basevertex });
}

pub fn drawRangeElementsBaseVertex(_mode: GLenum, _start: GLuint, _end: GLuint, _count: GLsizei, _type: GLenum, _indices: ?*const anyopaque, _basevertex: GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glDrawRangeElementsBaseVertex, .{ _mode, _start, _end, _count, _type, _indices, _basevertex });
}

pub fn drawElementsBaseVertex(_mode: GLenum, _count: GLsizei, _type: GLenum, _indices: ?*const anyopaque, _basevertex: GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glDrawElementsBaseVertex, .{ _mode, _count, _type, _indices, _basevertex });
}

pub fn genQueries(_n: GLsizei, _ids: [*c]GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGenQueries, .{ _n, _ids });
}

pub fn deleteQueries(_n: GLsizei, _ids: [*c]const GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glDeleteQueries, .{ _n, _ids });
}

pub fn isQuery(_id: GLuint) callconv(.C) GLboolean {
    return @call(.always_tail, function_pointers.glIsQuery, .{_id});
}

pub fn beginQuery(_target: GLenum, _id: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glBeginQuery, .{ _target, _id });
}

pub fn endQuery(_target: GLenum) callconv(.C) void {
    return @call(.always_tail, function_pointers.glEndQuery, .{_target});
}

pub fn getQueryiv(_target: GLenum, _pname: GLenum, _params: [*c]GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetQueryiv, .{ _target, _pname, _params });
}

pub fn getQueryObjectiv(_id: GLuint, _pname: GLenum, _params: [*c]GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetQueryObjectiv, .{ _id, _pname, _params });
}

pub fn getQueryObjectuiv(_id: GLuint, _pname: GLenum, _params: [*c]GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetQueryObjectuiv, .{ _id, _pname, _params });
}

pub fn bindBuffer(_target: GLenum, _buffer: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glBindBuffer, .{ _target, _buffer });
}

pub fn deleteBuffers(_n: GLsizei, _buffers: [*c]const GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glDeleteBuffers, .{ _n, _buffers });
}

pub fn genBuffers(_n: GLsizei, _buffers: [*c]GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGenBuffers, .{ _n, _buffers });
}

pub fn isBuffer(_buffer: GLuint) callconv(.C) GLboolean {
    return @call(.always_tail, function_pointers.glIsBuffer, .{_buffer});
}

pub fn bufferData(_target: GLenum, _size: GLsizeiptr, _data: ?*const anyopaque, _usage: GLenum) callconv(.C) void {
    return @call(.always_tail, function_pointers.glBufferData, .{ _target, _size, _data, _usage });
}

pub fn bufferSubData(_target: GLenum, _offset: GLintptr, _size: GLsizeiptr, _data: ?*const anyopaque) callconv(.C) void {
    return @call(.always_tail, function_pointers.glBufferSubData, .{ _target, _offset, _size, _data });
}

pub fn getBufferSubData(_target: GLenum, _offset: GLintptr, _size: GLsizeiptr, _data: ?*anyopaque) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetBufferSubData, .{ _target, _offset, _size, _data });
}

pub fn mapBuffer(_target: GLenum, _access: GLenum) callconv(.C) ?*anyopaque {
    return @call(.always_tail, function_pointers.glMapBuffer, .{ _target, _access });
}

pub fn unmapBuffer(_target: GLenum) callconv(.C) GLboolean {
    return @call(.always_tail, function_pointers.glUnmapBuffer, .{_target});
}

pub fn getBufferParameteriv(_target: GLenum, _pname: GLenum, _params: [*c]GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetBufferParameteriv, .{ _target, _pname, _params });
}

pub fn getBufferPointerv(_target: GLenum, _pname: GLenum, _params: ?*?*anyopaque) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetBufferPointerv, .{ _target, _pname, _params });
}

pub fn blendEquationSeparate(_modeRGB: GLenum, _modeAlpha: GLenum) callconv(.C) void {
    return @call(.always_tail, function_pointers.glBlendEquationSeparate, .{ _modeRGB, _modeAlpha });
}

pub fn drawBuffers(_n: GLsizei, _bufs: [*c]const GLenum) callconv(.C) void {
    return @call(.always_tail, function_pointers.glDrawBuffers, .{ _n, _bufs });
}

pub fn stencilOpSeparate(_face: GLenum, _sfail: GLenum, _dpfail: GLenum, _dppass: GLenum) callconv(.C) void {
    return @call(.always_tail, function_pointers.glStencilOpSeparate, .{ _face, _sfail, _dpfail, _dppass });
}

pub fn stencilFuncSeparate(_face: GLenum, _func: GLenum, _ref: GLint, _mask: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glStencilFuncSeparate, .{ _face, _func, _ref, _mask });
}

pub fn stencilMaskSeparate(_face: GLenum, _mask: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glStencilMaskSeparate, .{ _face, _mask });
}

pub fn attachShader(_program: GLuint, _shader: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glAttachShader, .{ _program, _shader });
}

pub fn bindAttribLocation(_program: GLuint, _index: GLuint, _name: [*c]const GLchar) callconv(.C) void {
    return @call(.always_tail, function_pointers.glBindAttribLocation, .{ _program, _index, _name });
}

pub fn compileShader(_shader: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glCompileShader, .{_shader});
}

pub fn createProgram() callconv(.C) GLuint {
    return @call(.always_tail, function_pointers.glCreateProgram, .{});
}

pub fn createShader(_type: GLenum) callconv(.C) GLuint {
    return @call(.always_tail, function_pointers.glCreateShader, .{_type});
}

pub fn deleteProgram(_program: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glDeleteProgram, .{_program});
}

pub fn deleteShader(_shader: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glDeleteShader, .{_shader});
}

pub fn detachShader(_program: GLuint, _shader: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glDetachShader, .{ _program, _shader });
}

pub fn disableVertexAttribArray(_index: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glDisableVertexAttribArray, .{_index});
}

pub fn enableVertexAttribArray(_index: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glEnableVertexAttribArray, .{_index});
}

pub fn getActiveAttrib(_program: GLuint, _index: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _size: [*c]GLint, _type: [*c]GLenum, _name: [*c]GLchar) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetActiveAttrib, .{ _program, _index, _bufSize, _length, _size, _type, _name });
}

pub fn getActiveUniform(_program: GLuint, _index: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _size: [*c]GLint, _type: [*c]GLenum, _name: [*c]GLchar) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetActiveUniform, .{ _program, _index, _bufSize, _length, _size, _type, _name });
}

pub fn getAttachedShaders(_program: GLuint, _maxCount: GLsizei, _count: [*c]GLsizei, _shaders: [*c]GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetAttachedShaders, .{ _program, _maxCount, _count, _shaders });
}

pub fn getAttribLocation(_program: GLuint, _name: [*c]const GLchar) callconv(.C) GLint {
    return @call(.always_tail, function_pointers.glGetAttribLocation, .{ _program, _name });
}

pub fn getProgramiv(_program: GLuint, _pname: GLenum, _params: [*c]GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetProgramiv, .{ _program, _pname, _params });
}

pub fn getProgramInfoLog(_program: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _infoLog: [*c]GLchar) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetProgramInfoLog, .{ _program, _bufSize, _length, _infoLog });
}

pub fn getShaderiv(_shader: GLuint, _pname: GLenum, _params: [*c]GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetShaderiv, .{ _shader, _pname, _params });
}

pub fn getShaderInfoLog(_shader: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _infoLog: [*c]GLchar) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetShaderInfoLog, .{ _shader, _bufSize, _length, _infoLog });
}

pub fn getShaderSource(_shader: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _source: [*c]GLchar) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetShaderSource, .{ _shader, _bufSize, _length, _source });
}

pub fn getUniformLocation(_program: GLuint, _name: [*c]const GLchar) callconv(.C) GLint {
    return @call(.always_tail, function_pointers.glGetUniformLocation, .{ _program, _name });
}

pub fn getUniformfv(_program: GLuint, _location: GLint, _params: [*c]GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetUniformfv, .{ _program, _location, _params });
}

pub fn getUniformiv(_program: GLuint, _location: GLint, _params: [*c]GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetUniformiv, .{ _program, _location, _params });
}

pub fn getVertexAttribdv(_index: GLuint, _pname: GLenum, _params: [*c]GLdouble) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetVertexAttribdv, .{ _index, _pname, _params });
}

pub fn getVertexAttribfv(_index: GLuint, _pname: GLenum, _params: [*c]GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetVertexAttribfv, .{ _index, _pname, _params });
}

pub fn getVertexAttribiv(_index: GLuint, _pname: GLenum, _params: [*c]GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetVertexAttribiv, .{ _index, _pname, _params });
}

pub fn getVertexAttribPointerv(_index: GLuint, _pname: GLenum, _pointer: ?*?*anyopaque) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetVertexAttribPointerv, .{ _index, _pname, _pointer });
}

pub fn isProgram(_program: GLuint) callconv(.C) GLboolean {
    return @call(.always_tail, function_pointers.glIsProgram, .{_program});
}

pub fn isShader(_shader: GLuint) callconv(.C) GLboolean {
    return @call(.always_tail, function_pointers.glIsShader, .{_shader});
}

pub fn linkProgram(_program: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glLinkProgram, .{_program});
}

pub fn shaderSource(_shader: GLuint, _count: GLsizei, _string: [*c]const [*c]const GLchar, _length: [*c]const GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glShaderSource, .{ _shader, _count, _string, _length });
}

pub fn useProgram(_program: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glUseProgram, .{_program});
}

pub fn uniform1f(_location: GLint, _v0: GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glUniform1f, .{ _location, _v0 });
}

pub fn uniform2f(_location: GLint, _v0: GLfloat, _v1: GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glUniform2f, .{ _location, _v0, _v1 });
}

pub fn uniform3f(_location: GLint, _v0: GLfloat, _v1: GLfloat, _v2: GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glUniform3f, .{ _location, _v0, _v1, _v2 });
}

pub fn uniform4f(_location: GLint, _v0: GLfloat, _v1: GLfloat, _v2: GLfloat, _v3: GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glUniform4f, .{ _location, _v0, _v1, _v2, _v3 });
}

pub fn uniform1i(_location: GLint, _v0: GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glUniform1i, .{ _location, _v0 });
}

pub fn uniform2i(_location: GLint, _v0: GLint, _v1: GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glUniform2i, .{ _location, _v0, _v1 });
}

pub fn uniform3i(_location: GLint, _v0: GLint, _v1: GLint, _v2: GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glUniform3i, .{ _location, _v0, _v1, _v2 });
}

pub fn uniform4i(_location: GLint, _v0: GLint, _v1: GLint, _v2: GLint, _v3: GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glUniform4i, .{ _location, _v0, _v1, _v2, _v3 });
}

pub fn uniform1fv(_location: GLint, _count: GLsizei, _value: [*c]const GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glUniform1fv, .{ _location, _count, _value });
}

pub fn uniform2fv(_location: GLint, _count: GLsizei, _value: [*c]const GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glUniform2fv, .{ _location, _count, _value });
}

pub fn uniform3fv(_location: GLint, _count: GLsizei, _value: [*c]const GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glUniform3fv, .{ _location, _count, _value });
}

pub fn uniform4fv(_location: GLint, _count: GLsizei, _value: [*c]const GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glUniform4fv, .{ _location, _count, _value });
}

pub fn uniform1iv(_location: GLint, _count: GLsizei, _value: [*c]const GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glUniform1iv, .{ _location, _count, _value });
}

pub fn uniform2iv(_location: GLint, _count: GLsizei, _value: [*c]const GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glUniform2iv, .{ _location, _count, _value });
}

pub fn uniform3iv(_location: GLint, _count: GLsizei, _value: [*c]const GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glUniform3iv, .{ _location, _count, _value });
}

pub fn uniform4iv(_location: GLint, _count: GLsizei, _value: [*c]const GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glUniform4iv, .{ _location, _count, _value });
}

pub fn uniformMatrix2fv(_location: GLint, _count: GLsizei, _transpose: GLboolean, _value: [*c]const GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glUniformMatrix2fv, .{ _location, _count, _transpose, _value });
}

pub fn uniformMatrix3fv(_location: GLint, _count: GLsizei, _transpose: GLboolean, _value: [*c]const GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glUniformMatrix3fv, .{ _location, _count, _transpose, _value });
}

pub fn uniformMatrix4fv(_location: GLint, _count: GLsizei, _transpose: GLboolean, _value: [*c]const GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glUniformMatrix4fv, .{ _location, _count, _transpose, _value });
}

pub fn validateProgram(_program: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glValidateProgram, .{_program});
}

pub fn vertexAttrib1d(_index: GLuint, _x: GLdouble) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttrib1d, .{ _index, _x });
}

pub fn vertexAttrib1dv(_index: GLuint, _v: [*c]const GLdouble) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttrib1dv, .{ _index, _v });
}

pub fn vertexAttrib1f(_index: GLuint, _x: GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttrib1f, .{ _index, _x });
}

pub fn vertexAttrib1fv(_index: GLuint, _v: [*c]const GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttrib1fv, .{ _index, _v });
}

pub fn vertexAttrib1s(_index: GLuint, _x: GLshort) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttrib1s, .{ _index, _x });
}

pub fn vertexAttrib1sv(_index: GLuint, _v: [*c]const GLshort) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttrib1sv, .{ _index, _v });
}

pub fn vertexAttrib2d(_index: GLuint, _x: GLdouble, _y: GLdouble) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttrib2d, .{ _index, _x, _y });
}

pub fn vertexAttrib2dv(_index: GLuint, _v: [*c]const GLdouble) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttrib2dv, .{ _index, _v });
}

pub fn vertexAttrib2f(_index: GLuint, _x: GLfloat, _y: GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttrib2f, .{ _index, _x, _y });
}

pub fn vertexAttrib2fv(_index: GLuint, _v: [*c]const GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttrib2fv, .{ _index, _v });
}

pub fn vertexAttrib2s(_index: GLuint, _x: GLshort, _y: GLshort) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttrib2s, .{ _index, _x, _y });
}

pub fn vertexAttrib2sv(_index: GLuint, _v: [*c]const GLshort) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttrib2sv, .{ _index, _v });
}

pub fn vertexAttrib3d(_index: GLuint, _x: GLdouble, _y: GLdouble, _z: GLdouble) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttrib3d, .{ _index, _x, _y, _z });
}

pub fn vertexAttrib3dv(_index: GLuint, _v: [*c]const GLdouble) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttrib3dv, .{ _index, _v });
}

pub fn vertexAttrib3f(_index: GLuint, _x: GLfloat, _y: GLfloat, _z: GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttrib3f, .{ _index, _x, _y, _z });
}

pub fn vertexAttrib3fv(_index: GLuint, _v: [*c]const GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttrib3fv, .{ _index, _v });
}

pub fn vertexAttrib3s(_index: GLuint, _x: GLshort, _y: GLshort, _z: GLshort) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttrib3s, .{ _index, _x, _y, _z });
}

pub fn vertexAttrib3sv(_index: GLuint, _v: [*c]const GLshort) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttrib3sv, .{ _index, _v });
}

pub fn vertexAttrib4Nbv(_index: GLuint, _v: [*c]const GLbyte) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttrib4Nbv, .{ _index, _v });
}

pub fn vertexAttrib4Niv(_index: GLuint, _v: [*c]const GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttrib4Niv, .{ _index, _v });
}

pub fn vertexAttrib4Nsv(_index: GLuint, _v: [*c]const GLshort) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttrib4Nsv, .{ _index, _v });
}

pub fn vertexAttrib4Nub(_index: GLuint, _x: GLubyte, _y: GLubyte, _z: GLubyte, _w: GLubyte) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttrib4Nub, .{ _index, _x, _y, _z, _w });
}

pub fn vertexAttrib4Nubv(_index: GLuint, _v: ?[*:0]const GLubyte) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttrib4Nubv, .{ _index, _v });
}

pub fn vertexAttrib4Nuiv(_index: GLuint, _v: [*c]const GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttrib4Nuiv, .{ _index, _v });
}

pub fn vertexAttrib4Nusv(_index: GLuint, _v: [*c]const GLushort) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttrib4Nusv, .{ _index, _v });
}

pub fn vertexAttrib4bv(_index: GLuint, _v: [*c]const GLbyte) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttrib4bv, .{ _index, _v });
}

pub fn vertexAttrib4d(_index: GLuint, _x: GLdouble, _y: GLdouble, _z: GLdouble, _w: GLdouble) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttrib4d, .{ _index, _x, _y, _z, _w });
}

pub fn vertexAttrib4dv(_index: GLuint, _v: [*c]const GLdouble) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttrib4dv, .{ _index, _v });
}

pub fn vertexAttrib4f(_index: GLuint, _x: GLfloat, _y: GLfloat, _z: GLfloat, _w: GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttrib4f, .{ _index, _x, _y, _z, _w });
}

pub fn vertexAttrib4fv(_index: GLuint, _v: [*c]const GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttrib4fv, .{ _index, _v });
}

pub fn vertexAttrib4iv(_index: GLuint, _v: [*c]const GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttrib4iv, .{ _index, _v });
}

pub fn vertexAttrib4s(_index: GLuint, _x: GLshort, _y: GLshort, _z: GLshort, _w: GLshort) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttrib4s, .{ _index, _x, _y, _z, _w });
}

pub fn vertexAttrib4sv(_index: GLuint, _v: [*c]const GLshort) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttrib4sv, .{ _index, _v });
}

pub fn vertexAttrib4ubv(_index: GLuint, _v: ?[*:0]const GLubyte) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttrib4ubv, .{ _index, _v });
}

pub fn vertexAttrib4uiv(_index: GLuint, _v: [*c]const GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttrib4uiv, .{ _index, _v });
}

pub fn vertexAttrib4usv(_index: GLuint, _v: [*c]const GLushort) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttrib4usv, .{ _index, _v });
}

pub fn vertexAttribPointer(_index: GLuint, _size: GLint, _type: GLenum, _normalized: GLboolean, _stride: GLsizei, _pointer: ?*const anyopaque) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttribPointer, .{ _index, _size, _type, _normalized, _stride, _pointer });
}

pub fn uniformMatrix2x3fv(_location: GLint, _count: GLsizei, _transpose: GLboolean, _value: [*c]const GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glUniformMatrix2x3fv, .{ _location, _count, _transpose, _value });
}

pub fn uniformMatrix3x2fv(_location: GLint, _count: GLsizei, _transpose: GLboolean, _value: [*c]const GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glUniformMatrix3x2fv, .{ _location, _count, _transpose, _value });
}

pub fn uniformMatrix2x4fv(_location: GLint, _count: GLsizei, _transpose: GLboolean, _value: [*c]const GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glUniformMatrix2x4fv, .{ _location, _count, _transpose, _value });
}

pub fn uniformMatrix4x2fv(_location: GLint, _count: GLsizei, _transpose: GLboolean, _value: [*c]const GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glUniformMatrix4x2fv, .{ _location, _count, _transpose, _value });
}

pub fn uniformMatrix3x4fv(_location: GLint, _count: GLsizei, _transpose: GLboolean, _value: [*c]const GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glUniformMatrix3x4fv, .{ _location, _count, _transpose, _value });
}

pub fn uniformMatrix4x3fv(_location: GLint, _count: GLsizei, _transpose: GLboolean, _value: [*c]const GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glUniformMatrix4x3fv, .{ _location, _count, _transpose, _value });
}

pub fn colorMaski(_index: GLuint, _r: GLboolean, _g: GLboolean, _b: GLboolean, _a: GLboolean) callconv(.C) void {
    return @call(.always_tail, function_pointers.glColorMaski, .{ _index, _r, _g, _b, _a });
}

pub fn getBooleani_v(_target: GLenum, _index: GLuint, _data: [*c]GLboolean) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetBooleani_v, .{ _target, _index, _data });
}

pub fn getIntegeri_v(_target: GLenum, _index: GLuint, _data: [*c]GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetIntegeri_v, .{ _target, _index, _data });
}

pub fn enablei(_target: GLenum, _index: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glEnablei, .{ _target, _index });
}

pub fn disablei(_target: GLenum, _index: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glDisablei, .{ _target, _index });
}

pub fn isEnabledi(_target: GLenum, _index: GLuint) callconv(.C) GLboolean {
    return @call(.always_tail, function_pointers.glIsEnabledi, .{ _target, _index });
}

pub fn beginTransformFeedback(_primitiveMode: GLenum) callconv(.C) void {
    return @call(.always_tail, function_pointers.glBeginTransformFeedback, .{_primitiveMode});
}

pub fn endTransformFeedback() callconv(.C) void {
    return @call(.always_tail, function_pointers.glEndTransformFeedback, .{});
}

pub fn bindBufferRange(_target: GLenum, _index: GLuint, _buffer: GLuint, _offset: GLintptr, _size: GLsizeiptr) callconv(.C) void {
    return @call(.always_tail, function_pointers.glBindBufferRange, .{ _target, _index, _buffer, _offset, _size });
}

pub fn bindBufferBase(_target: GLenum, _index: GLuint, _buffer: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glBindBufferBase, .{ _target, _index, _buffer });
}

pub fn transformFeedbackVaryings(_program: GLuint, _count: GLsizei, _varyings: [*c]const [*c]const GLchar, _bufferMode: GLenum) callconv(.C) void {
    return @call(.always_tail, function_pointers.glTransformFeedbackVaryings, .{ _program, _count, _varyings, _bufferMode });
}

pub fn getTransformFeedbackVarying(_program: GLuint, _index: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _size: [*c]GLsizei, _type: [*c]GLenum, _name: [*c]GLchar) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetTransformFeedbackVarying, .{ _program, _index, _bufSize, _length, _size, _type, _name });
}

pub fn clampColor(_target: GLenum, _clamp: GLenum) callconv(.C) void {
    return @call(.always_tail, function_pointers.glClampColor, .{ _target, _clamp });
}

pub fn beginConditionalRender(_id: GLuint, _mode: GLenum) callconv(.C) void {
    return @call(.always_tail, function_pointers.glBeginConditionalRender, .{ _id, _mode });
}

pub fn endConditionalRender() callconv(.C) void {
    return @call(.always_tail, function_pointers.glEndConditionalRender, .{});
}

pub fn vertexAttribIPointer(_index: GLuint, _size: GLint, _type: GLenum, _stride: GLsizei, _pointer: ?*const anyopaque) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttribIPointer, .{ _index, _size, _type, _stride, _pointer });
}

pub fn getVertexAttribIiv(_index: GLuint, _pname: GLenum, _params: [*c]GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetVertexAttribIiv, .{ _index, _pname, _params });
}

pub fn getVertexAttribIuiv(_index: GLuint, _pname: GLenum, _params: [*c]GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetVertexAttribIuiv, .{ _index, _pname, _params });
}

pub fn vertexAttribI1i(_index: GLuint, _x: GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttribI1i, .{ _index, _x });
}

pub fn vertexAttribI2i(_index: GLuint, _x: GLint, _y: GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttribI2i, .{ _index, _x, _y });
}

pub fn vertexAttribI3i(_index: GLuint, _x: GLint, _y: GLint, _z: GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttribI3i, .{ _index, _x, _y, _z });
}

pub fn vertexAttribI4i(_index: GLuint, _x: GLint, _y: GLint, _z: GLint, _w: GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttribI4i, .{ _index, _x, _y, _z, _w });
}

pub fn vertexAttribI1ui(_index: GLuint, _x: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttribI1ui, .{ _index, _x });
}

pub fn vertexAttribI2ui(_index: GLuint, _x: GLuint, _y: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttribI2ui, .{ _index, _x, _y });
}

pub fn vertexAttribI3ui(_index: GLuint, _x: GLuint, _y: GLuint, _z: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttribI3ui, .{ _index, _x, _y, _z });
}

pub fn vertexAttribI4ui(_index: GLuint, _x: GLuint, _y: GLuint, _z: GLuint, _w: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttribI4ui, .{ _index, _x, _y, _z, _w });
}

pub fn vertexAttribI1iv(_index: GLuint, _v: [*c]const GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttribI1iv, .{ _index, _v });
}

pub fn vertexAttribI2iv(_index: GLuint, _v: [*c]const GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttribI2iv, .{ _index, _v });
}

pub fn vertexAttribI3iv(_index: GLuint, _v: [*c]const GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttribI3iv, .{ _index, _v });
}

pub fn vertexAttribI4iv(_index: GLuint, _v: [*c]const GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttribI4iv, .{ _index, _v });
}

pub fn vertexAttribI1uiv(_index: GLuint, _v: [*c]const GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttribI1uiv, .{ _index, _v });
}

pub fn vertexAttribI2uiv(_index: GLuint, _v: [*c]const GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttribI2uiv, .{ _index, _v });
}

pub fn vertexAttribI3uiv(_index: GLuint, _v: [*c]const GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttribI3uiv, .{ _index, _v });
}

pub fn vertexAttribI4uiv(_index: GLuint, _v: [*c]const GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttribI4uiv, .{ _index, _v });
}

pub fn vertexAttribI4bv(_index: GLuint, _v: [*c]const GLbyte) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttribI4bv, .{ _index, _v });
}

pub fn vertexAttribI4sv(_index: GLuint, _v: [*c]const GLshort) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttribI4sv, .{ _index, _v });
}

pub fn vertexAttribI4ubv(_index: GLuint, _v: ?[*:0]const GLubyte) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttribI4ubv, .{ _index, _v });
}

pub fn vertexAttribI4usv(_index: GLuint, _v: [*c]const GLushort) callconv(.C) void {
    return @call(.always_tail, function_pointers.glVertexAttribI4usv, .{ _index, _v });
}

pub fn getUniformuiv(_program: GLuint, _location: GLint, _params: [*c]GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetUniformuiv, .{ _program, _location, _params });
}

pub fn bindFragDataLocation(_program: GLuint, _color: GLuint, _name: [*c]const GLchar) callconv(.C) void {
    return @call(.always_tail, function_pointers.glBindFragDataLocation, .{ _program, _color, _name });
}

pub fn getFragDataLocation(_program: GLuint, _name: [*c]const GLchar) callconv(.C) GLint {
    return @call(.always_tail, function_pointers.glGetFragDataLocation, .{ _program, _name });
}

pub fn uniform1ui(_location: GLint, _v0: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glUniform1ui, .{ _location, _v0 });
}

pub fn uniform2ui(_location: GLint, _v0: GLuint, _v1: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glUniform2ui, .{ _location, _v0, _v1 });
}

pub fn uniform3ui(_location: GLint, _v0: GLuint, _v1: GLuint, _v2: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glUniform3ui, .{ _location, _v0, _v1, _v2 });
}

pub fn uniform4ui(_location: GLint, _v0: GLuint, _v1: GLuint, _v2: GLuint, _v3: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glUniform4ui, .{ _location, _v0, _v1, _v2, _v3 });
}

pub fn uniform1uiv(_location: GLint, _count: GLsizei, _value: [*c]const GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glUniform1uiv, .{ _location, _count, _value });
}

pub fn uniform2uiv(_location: GLint, _count: GLsizei, _value: [*c]const GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glUniform2uiv, .{ _location, _count, _value });
}

pub fn uniform3uiv(_location: GLint, _count: GLsizei, _value: [*c]const GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glUniform3uiv, .{ _location, _count, _value });
}

pub fn uniform4uiv(_location: GLint, _count: GLsizei, _value: [*c]const GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glUniform4uiv, .{ _location, _count, _value });
}

pub fn texParameterIiv(_target: GLenum, _pname: GLenum, _params: [*c]const GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glTexParameterIiv, .{ _target, _pname, _params });
}

pub fn texParameterIuiv(_target: GLenum, _pname: GLenum, _params: [*c]const GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glTexParameterIuiv, .{ _target, _pname, _params });
}

pub fn getTexParameterIiv(_target: GLenum, _pname: GLenum, _params: [*c]GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetTexParameterIiv, .{ _target, _pname, _params });
}

pub fn getTexParameterIuiv(_target: GLenum, _pname: GLenum, _params: [*c]GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetTexParameterIuiv, .{ _target, _pname, _params });
}

pub fn clearBufferiv(_buffer: GLenum, _drawbuffer: GLint, _value: [*c]const GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glClearBufferiv, .{ _buffer, _drawbuffer, _value });
}

pub fn clearBufferuiv(_buffer: GLenum, _drawbuffer: GLint, _value: [*c]const GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glClearBufferuiv, .{ _buffer, _drawbuffer, _value });
}

pub fn clearBufferfv(_buffer: GLenum, _drawbuffer: GLint, _value: [*c]const GLfloat) callconv(.C) void {
    return @call(.always_tail, function_pointers.glClearBufferfv, .{ _buffer, _drawbuffer, _value });
}

pub fn clearBufferfi(_buffer: GLenum, _drawbuffer: GLint, _depth: GLfloat, _stencil: GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glClearBufferfi, .{ _buffer, _drawbuffer, _depth, _stencil });
}

pub fn getStringi(_name: GLenum, _index: GLuint) callconv(.C) ?[*:0]const GLubyte {
    return @call(.always_tail, function_pointers.glGetStringi, .{ _name, _index });
}

pub fn isRenderbuffer(_renderbuffer: GLuint) callconv(.C) GLboolean {
    return @call(.always_tail, function_pointers.glIsRenderbuffer, .{_renderbuffer});
}

pub fn bindRenderbuffer(_target: GLenum, _renderbuffer: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glBindRenderbuffer, .{ _target, _renderbuffer });
}

pub fn deleteRenderbuffers(_n: GLsizei, _renderbuffers: [*c]const GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glDeleteRenderbuffers, .{ _n, _renderbuffers });
}

pub fn genRenderbuffers(_n: GLsizei, _renderbuffers: [*c]GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGenRenderbuffers, .{ _n, _renderbuffers });
}

pub fn renderbufferStorage(_target: GLenum, _internalformat: GLenum, _width: GLsizei, _height: GLsizei) callconv(.C) void {
    return @call(.always_tail, function_pointers.glRenderbufferStorage, .{ _target, _internalformat, _width, _height });
}

pub fn getRenderbufferParameteriv(_target: GLenum, _pname: GLenum, _params: [*c]GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetRenderbufferParameteriv, .{ _target, _pname, _params });
}

pub fn isFramebuffer(_framebuffer: GLuint) callconv(.C) GLboolean {
    return @call(.always_tail, function_pointers.glIsFramebuffer, .{_framebuffer});
}

pub fn bindFramebuffer(_target: GLenum, _framebuffer: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glBindFramebuffer, .{ _target, _framebuffer });
}

pub fn deleteFramebuffers(_n: GLsizei, _framebuffers: [*c]const GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glDeleteFramebuffers, .{ _n, _framebuffers });
}

pub fn genFramebuffers(_n: GLsizei, _framebuffers: [*c]GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGenFramebuffers, .{ _n, _framebuffers });
}

pub fn checkFramebufferStatus(_target: GLenum) callconv(.C) GLenum {
    return @call(.always_tail, function_pointers.glCheckFramebufferStatus, .{_target});
}

pub fn framebufferTexture1D(_target: GLenum, _attachment: GLenum, _textarget: GLenum, _texture: GLuint, _level: GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glFramebufferTexture1D, .{ _target, _attachment, _textarget, _texture, _level });
}

pub fn framebufferTexture2D(_target: GLenum, _attachment: GLenum, _textarget: GLenum, _texture: GLuint, _level: GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glFramebufferTexture2D, .{ _target, _attachment, _textarget, _texture, _level });
}

pub fn framebufferTexture3D(_target: GLenum, _attachment: GLenum, _textarget: GLenum, _texture: GLuint, _level: GLint, _zoffset: GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glFramebufferTexture3D, .{ _target, _attachment, _textarget, _texture, _level, _zoffset });
}

pub fn framebufferRenderbuffer(_target: GLenum, _attachment: GLenum, _renderbuffertarget: GLenum, _renderbuffer: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glFramebufferRenderbuffer, .{ _target, _attachment, _renderbuffertarget, _renderbuffer });
}

pub fn getFramebufferAttachmentParameteriv(_target: GLenum, _attachment: GLenum, _pname: GLenum, _params: [*c]GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetFramebufferAttachmentParameteriv, .{ _target, _attachment, _pname, _params });
}

pub fn generateMipmap(_target: GLenum) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGenerateMipmap, .{_target});
}

pub fn blitFramebuffer(_srcX0: GLint, _srcY0: GLint, _srcX1: GLint, _srcY1: GLint, _dstX0: GLint, _dstY0: GLint, _dstX1: GLint, _dstY1: GLint, _mask: GLbitfield, _filter: GLenum) callconv(.C) void {
    return @call(.always_tail, function_pointers.glBlitFramebuffer, .{ _srcX0, _srcY0, _srcX1, _srcY1, _dstX0, _dstY0, _dstX1, _dstY1, _mask, _filter });
}

pub fn renderbufferStorageMultisample(_target: GLenum, _samples: GLsizei, _internalformat: GLenum, _width: GLsizei, _height: GLsizei) callconv(.C) void {
    return @call(.always_tail, function_pointers.glRenderbufferStorageMultisample, .{ _target, _samples, _internalformat, _width, _height });
}

pub fn framebufferTextureLayer(_target: GLenum, _attachment: GLenum, _texture: GLuint, _level: GLint, _layer: GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glFramebufferTextureLayer, .{ _target, _attachment, _texture, _level, _layer });
}

pub fn mapBufferRange(_target: GLenum, _offset: GLintptr, _length: GLsizeiptr, _access: GLbitfield) callconv(.C) ?*anyopaque {
    return @call(.always_tail, function_pointers.glMapBufferRange, .{ _target, _offset, _length, _access });
}

pub fn flushMappedBufferRange(_target: GLenum, _offset: GLintptr, _length: GLsizeiptr) callconv(.C) void {
    return @call(.always_tail, function_pointers.glFlushMappedBufferRange, .{ _target, _offset, _length });
}

pub fn bindVertexArray(_array: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glBindVertexArray, .{_array});
}

pub fn deleteVertexArrays(_n: GLsizei, _arrays: [*c]const GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glDeleteVertexArrays, .{ _n, _arrays });
}

pub fn genVertexArrays(_n: GLsizei, _arrays: [*c]GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGenVertexArrays, .{ _n, _arrays });
}

pub fn isVertexArray(_array: GLuint) callconv(.C) GLboolean {
    return @call(.always_tail, function_pointers.glIsVertexArray, .{_array});
}

pub fn drawArraysInstanced(_mode: GLenum, _first: GLint, _count: GLsizei, _instancecount: GLsizei) callconv(.C) void {
    return @call(.always_tail, function_pointers.glDrawArraysInstanced, .{ _mode, _first, _count, _instancecount });
}

pub fn drawElementsInstanced(_mode: GLenum, _count: GLsizei, _type: GLenum, _indices: ?*const anyopaque, _instancecount: GLsizei) callconv(.C) void {
    return @call(.always_tail, function_pointers.glDrawElementsInstanced, .{ _mode, _count, _type, _indices, _instancecount });
}

pub fn texBuffer(_target: GLenum, _internalformat: GLenum, _buffer: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glTexBuffer, .{ _target, _internalformat, _buffer });
}

pub fn primitiveRestartIndex(_index: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glPrimitiveRestartIndex, .{_index});
}

pub fn copyBufferSubData(_readTarget: GLenum, _writeTarget: GLenum, _readOffset: GLintptr, _writeOffset: GLintptr, _size: GLsizeiptr) callconv(.C) void {
    return @call(.always_tail, function_pointers.glCopyBufferSubData, .{ _readTarget, _writeTarget, _readOffset, _writeOffset, _size });
}

pub fn getUniformIndices(_program: GLuint, _uniformCount: GLsizei, _uniformNames: [*c]const [*c]const GLchar, _uniformIndices: [*c]GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetUniformIndices, .{ _program, _uniformCount, _uniformNames, _uniformIndices });
}

pub fn getActiveUniformsiv(_program: GLuint, _uniformCount: GLsizei, _uniformIndices: [*c]const GLuint, _pname: GLenum, _params: [*c]GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetActiveUniformsiv, .{ _program, _uniformCount, _uniformIndices, _pname, _params });
}

pub fn getActiveUniformName(_program: GLuint, _uniformIndex: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _uniformName: [*c]GLchar) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetActiveUniformName, .{ _program, _uniformIndex, _bufSize, _length, _uniformName });
}

pub fn getUniformBlockIndex(_program: GLuint, _uniformBlockName: [*c]const GLchar) callconv(.C) GLuint {
    return @call(.always_tail, function_pointers.glGetUniformBlockIndex, .{ _program, _uniformBlockName });
}

pub fn getActiveUniformBlockiv(_program: GLuint, _uniformBlockIndex: GLuint, _pname: GLenum, _params: [*c]GLint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetActiveUniformBlockiv, .{ _program, _uniformBlockIndex, _pname, _params });
}

pub fn getActiveUniformBlockName(_program: GLuint, _uniformBlockIndex: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _uniformBlockName: [*c]GLchar) callconv(.C) void {
    return @call(.always_tail, function_pointers.glGetActiveUniformBlockName, .{ _program, _uniformBlockIndex, _bufSize, _length, _uniformBlockName });
}

pub fn uniformBlockBinding(_program: GLuint, _uniformBlockIndex: GLuint, _uniformBlockBinding: GLuint) callconv(.C) void {
    return @call(.always_tail, function_pointers.glUniformBlockBinding, .{ _program, _uniformBlockIndex, _uniformBlockBinding });
}
// Extensions:

// Loader API:
pub fn load(load_ctx: anytype, get_proc_address: fn (@TypeOf(load_ctx), [:0]const u8) ?FunctionPointer) !void {
    var success = true;
    if (get_proc_address(load_ctx, "glCullFace")) |proc| {
        function_pointers.glCullFace = @as(@TypeOf(function_pointers.glCullFace), @ptrCast(proc));
    } else {
        log.err("entry point glCullFace not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glFrontFace")) |proc| {
        function_pointers.glFrontFace = @as(@TypeOf(function_pointers.glFrontFace), @ptrCast(proc));
    } else {
        log.err("entry point glFrontFace not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glHint")) |proc| {
        function_pointers.glHint = @as(@TypeOf(function_pointers.glHint), @ptrCast(proc));
    } else {
        log.err("entry point glHint not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glLineWidth")) |proc| {
        function_pointers.glLineWidth = @as(@TypeOf(function_pointers.glLineWidth), @ptrCast(proc));
    } else {
        log.err("entry point glLineWidth not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glPointSize")) |proc| {
        function_pointers.glPointSize = @as(@TypeOf(function_pointers.glPointSize), @ptrCast(proc));
    } else {
        log.err("entry point glPointSize not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glPolygonMode")) |proc| {
        function_pointers.glPolygonMode = @as(@TypeOf(function_pointers.glPolygonMode), @ptrCast(proc));
    } else {
        log.err("entry point glPolygonMode not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glScissor")) |proc| {
        function_pointers.glScissor = @as(@TypeOf(function_pointers.glScissor), @ptrCast(proc));
    } else {
        log.err("entry point glScissor not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glTexParameterf")) |proc| {
        function_pointers.glTexParameterf = @as(@TypeOf(function_pointers.glTexParameterf), @ptrCast(proc));
    } else {
        log.err("entry point glTexParameterf not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glTexParameterfv")) |proc| {
        function_pointers.glTexParameterfv = @as(@TypeOf(function_pointers.glTexParameterfv), @ptrCast(proc));
    } else {
        log.err("entry point glTexParameterfv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glTexParameteri")) |proc| {
        function_pointers.glTexParameteri = @as(@TypeOf(function_pointers.glTexParameteri), @ptrCast(proc));
    } else {
        log.err("entry point glTexParameteri not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glTexParameteriv")) |proc| {
        function_pointers.glTexParameteriv = @as(@TypeOf(function_pointers.glTexParameteriv), @ptrCast(proc));
    } else {
        log.err("entry point glTexParameteriv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glTexImage1D")) |proc| {
        function_pointers.glTexImage1D = @as(@TypeOf(function_pointers.glTexImage1D), @ptrCast(proc));
    } else {
        log.err("entry point glTexImage1D not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glTexImage2D")) |proc| {
        function_pointers.glTexImage2D = @as(@TypeOf(function_pointers.glTexImage2D), @ptrCast(proc));
    } else {
        log.err("entry point glTexImage2D not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glDrawBuffer")) |proc| {
        function_pointers.glDrawBuffer = @as(@TypeOf(function_pointers.glDrawBuffer), @ptrCast(proc));
    } else {
        log.err("entry point glDrawBuffer not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glClear")) |proc| {
        function_pointers.glClear = @as(@TypeOf(function_pointers.glClear), @ptrCast(proc));
    } else {
        log.err("entry point glClear not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glClearColor")) |proc| {
        function_pointers.glClearColor = @as(@TypeOf(function_pointers.glClearColor), @ptrCast(proc));
    } else {
        log.err("entry point glClearColor not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glClearStencil")) |proc| {
        function_pointers.glClearStencil = @as(@TypeOf(function_pointers.glClearStencil), @ptrCast(proc));
    } else {
        log.err("entry point glClearStencil not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glClearDepth")) |proc| {
        function_pointers.glClearDepth = @as(@TypeOf(function_pointers.glClearDepth), @ptrCast(proc));
    } else {
        log.err("entry point glClearDepth not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glStencilMask")) |proc| {
        function_pointers.glStencilMask = @as(@TypeOf(function_pointers.glStencilMask), @ptrCast(proc));
    } else {
        log.err("entry point glStencilMask not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glColorMask")) |proc| {
        function_pointers.glColorMask = @as(@TypeOf(function_pointers.glColorMask), @ptrCast(proc));
    } else {
        log.err("entry point glColorMask not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glDepthMask")) |proc| {
        function_pointers.glDepthMask = @as(@TypeOf(function_pointers.glDepthMask), @ptrCast(proc));
    } else {
        log.err("entry point glDepthMask not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glDisable")) |proc| {
        function_pointers.glDisable = @as(@TypeOf(function_pointers.glDisable), @ptrCast(proc));
    } else {
        log.err("entry point glDisable not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glEnable")) |proc| {
        function_pointers.glEnable = @as(@TypeOf(function_pointers.glEnable), @ptrCast(proc));
    } else {
        log.err("entry point glEnable not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glFinish")) |proc| {
        function_pointers.glFinish = @as(@TypeOf(function_pointers.glFinish), @ptrCast(proc));
    } else {
        log.err("entry point glFinish not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glFlush")) |proc| {
        function_pointers.glFlush = @as(@TypeOf(function_pointers.glFlush), @ptrCast(proc));
    } else {
        log.err("entry point glFlush not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glBlendFunc")) |proc| {
        function_pointers.glBlendFunc = @as(@TypeOf(function_pointers.glBlendFunc), @ptrCast(proc));
    } else {
        log.err("entry point glBlendFunc not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glLogicOp")) |proc| {
        function_pointers.glLogicOp = @as(@TypeOf(function_pointers.glLogicOp), @ptrCast(proc));
    } else {
        log.err("entry point glLogicOp not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glStencilFunc")) |proc| {
        function_pointers.glStencilFunc = @as(@TypeOf(function_pointers.glStencilFunc), @ptrCast(proc));
    } else {
        log.err("entry point glStencilFunc not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glStencilOp")) |proc| {
        function_pointers.glStencilOp = @as(@TypeOf(function_pointers.glStencilOp), @ptrCast(proc));
    } else {
        log.err("entry point glStencilOp not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glDepthFunc")) |proc| {
        function_pointers.glDepthFunc = @as(@TypeOf(function_pointers.glDepthFunc), @ptrCast(proc));
    } else {
        log.err("entry point glDepthFunc not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glPixelStoref")) |proc| {
        function_pointers.glPixelStoref = @as(@TypeOf(function_pointers.glPixelStoref), @ptrCast(proc));
    } else {
        log.err("entry point glPixelStoref not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glPixelStorei")) |proc| {
        function_pointers.glPixelStorei = @as(@TypeOf(function_pointers.glPixelStorei), @ptrCast(proc));
    } else {
        log.err("entry point glPixelStorei not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glReadBuffer")) |proc| {
        function_pointers.glReadBuffer = @as(@TypeOf(function_pointers.glReadBuffer), @ptrCast(proc));
    } else {
        log.err("entry point glReadBuffer not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glReadPixels")) |proc| {
        function_pointers.glReadPixels = @as(@TypeOf(function_pointers.glReadPixels), @ptrCast(proc));
    } else {
        log.err("entry point glReadPixels not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetBooleanv")) |proc| {
        function_pointers.glGetBooleanv = @as(@TypeOf(function_pointers.glGetBooleanv), @ptrCast(proc));
    } else {
        log.err("entry point glGetBooleanv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetDoublev")) |proc| {
        function_pointers.glGetDoublev = @as(@TypeOf(function_pointers.glGetDoublev), @ptrCast(proc));
    } else {
        log.err("entry point glGetDoublev not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetError")) |proc| {
        function_pointers.glGetError = @as(@TypeOf(function_pointers.glGetError), @ptrCast(proc));
    } else {
        log.err("entry point glGetError not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetFloatv")) |proc| {
        function_pointers.glGetFloatv = @as(@TypeOf(function_pointers.glGetFloatv), @ptrCast(proc));
    } else {
        log.err("entry point glGetFloatv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetIntegerv")) |proc| {
        function_pointers.glGetIntegerv = @as(@TypeOf(function_pointers.glGetIntegerv), @ptrCast(proc));
    } else {
        log.err("entry point glGetIntegerv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetString")) |proc| {
        function_pointers.glGetString = @as(@TypeOf(function_pointers.glGetString), @ptrCast(proc));
    } else {
        log.err("entry point glGetString not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetTexImage")) |proc| {
        function_pointers.glGetTexImage = @as(@TypeOf(function_pointers.glGetTexImage), @ptrCast(proc));
    } else {
        log.err("entry point glGetTexImage not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetTexParameterfv")) |proc| {
        function_pointers.glGetTexParameterfv = @as(@TypeOf(function_pointers.glGetTexParameterfv), @ptrCast(proc));
    } else {
        log.err("entry point glGetTexParameterfv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetTexParameteriv")) |proc| {
        function_pointers.glGetTexParameteriv = @as(@TypeOf(function_pointers.glGetTexParameteriv), @ptrCast(proc));
    } else {
        log.err("entry point glGetTexParameteriv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetTexLevelParameterfv")) |proc| {
        function_pointers.glGetTexLevelParameterfv = @as(@TypeOf(function_pointers.glGetTexLevelParameterfv), @ptrCast(proc));
    } else {
        log.err("entry point glGetTexLevelParameterfv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetTexLevelParameteriv")) |proc| {
        function_pointers.glGetTexLevelParameteriv = @as(@TypeOf(function_pointers.glGetTexLevelParameteriv), @ptrCast(proc));
    } else {
        log.err("entry point glGetTexLevelParameteriv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glIsEnabled")) |proc| {
        function_pointers.glIsEnabled = @as(@TypeOf(function_pointers.glIsEnabled), @ptrCast(proc));
    } else {
        log.err("entry point glIsEnabled not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glDepthRange")) |proc| {
        function_pointers.glDepthRange = @as(@TypeOf(function_pointers.glDepthRange), @ptrCast(proc));
    } else {
        log.err("entry point glDepthRange not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glViewport")) |proc| {
        function_pointers.glViewport = @as(@TypeOf(function_pointers.glViewport), @ptrCast(proc));
    } else {
        log.err("entry point glViewport not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glDrawArrays")) |proc| {
        function_pointers.glDrawArrays = @as(@TypeOf(function_pointers.glDrawArrays), @ptrCast(proc));
    } else {
        log.err("entry point glDrawArrays not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glDrawElements")) |proc| {
        function_pointers.glDrawElements = @as(@TypeOf(function_pointers.glDrawElements), @ptrCast(proc));
    } else {
        log.err("entry point glDrawElements not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glPolygonOffset")) |proc| {
        function_pointers.glPolygonOffset = @as(@TypeOf(function_pointers.glPolygonOffset), @ptrCast(proc));
    } else {
        log.err("entry point glPolygonOffset not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glCopyTexImage1D")) |proc| {
        function_pointers.glCopyTexImage1D = @as(@TypeOf(function_pointers.glCopyTexImage1D), @ptrCast(proc));
    } else {
        log.err("entry point glCopyTexImage1D not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glCopyTexImage2D")) |proc| {
        function_pointers.glCopyTexImage2D = @as(@TypeOf(function_pointers.glCopyTexImage2D), @ptrCast(proc));
    } else {
        log.err("entry point glCopyTexImage2D not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glCopyTexSubImage1D")) |proc| {
        function_pointers.glCopyTexSubImage1D = @as(@TypeOf(function_pointers.glCopyTexSubImage1D), @ptrCast(proc));
    } else {
        log.err("entry point glCopyTexSubImage1D not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glCopyTexSubImage2D")) |proc| {
        function_pointers.glCopyTexSubImage2D = @as(@TypeOf(function_pointers.glCopyTexSubImage2D), @ptrCast(proc));
    } else {
        log.err("entry point glCopyTexSubImage2D not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glTexSubImage1D")) |proc| {
        function_pointers.glTexSubImage1D = @as(@TypeOf(function_pointers.glTexSubImage1D), @ptrCast(proc));
    } else {
        log.err("entry point glTexSubImage1D not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glTexSubImage2D")) |proc| {
        function_pointers.glTexSubImage2D = @as(@TypeOf(function_pointers.glTexSubImage2D), @ptrCast(proc));
    } else {
        log.err("entry point glTexSubImage2D not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glBindTexture")) |proc| {
        function_pointers.glBindTexture = @as(@TypeOf(function_pointers.glBindTexture), @ptrCast(proc));
    } else {
        log.err("entry point glBindTexture not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glDeleteTextures")) |proc| {
        function_pointers.glDeleteTextures = @as(@TypeOf(function_pointers.glDeleteTextures), @ptrCast(proc));
    } else {
        log.err("entry point glDeleteTextures not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGenTextures")) |proc| {
        function_pointers.glGenTextures = @as(@TypeOf(function_pointers.glGenTextures), @ptrCast(proc));
    } else {
        log.err("entry point glGenTextures not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glIsTexture")) |proc| {
        function_pointers.glIsTexture = @as(@TypeOf(function_pointers.glIsTexture), @ptrCast(proc));
    } else {
        log.err("entry point glIsTexture not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glDrawRangeElements")) |proc| {
        function_pointers.glDrawRangeElements = @as(@TypeOf(function_pointers.glDrawRangeElements), @ptrCast(proc));
    } else {
        log.err("entry point glDrawRangeElements not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glTexImage3D")) |proc| {
        function_pointers.glTexImage3D = @as(@TypeOf(function_pointers.glTexImage3D), @ptrCast(proc));
    } else {
        log.err("entry point glTexImage3D not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glTexSubImage3D")) |proc| {
        function_pointers.glTexSubImage3D = @as(@TypeOf(function_pointers.glTexSubImage3D), @ptrCast(proc));
    } else {
        log.err("entry point glTexSubImage3D not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glCopyTexSubImage3D")) |proc| {
        function_pointers.glCopyTexSubImage3D = @as(@TypeOf(function_pointers.glCopyTexSubImage3D), @ptrCast(proc));
    } else {
        log.err("entry point glCopyTexSubImage3D not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glActiveTexture")) |proc| {
        function_pointers.glActiveTexture = @as(@TypeOf(function_pointers.glActiveTexture), @ptrCast(proc));
    } else {
        log.err("entry point glActiveTexture not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glSampleCoverage")) |proc| {
        function_pointers.glSampleCoverage = @as(@TypeOf(function_pointers.glSampleCoverage), @ptrCast(proc));
    } else {
        log.err("entry point glSampleCoverage not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glCompressedTexImage3D")) |proc| {
        function_pointers.glCompressedTexImage3D = @as(@TypeOf(function_pointers.glCompressedTexImage3D), @ptrCast(proc));
    } else {
        log.err("entry point glCompressedTexImage3D not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glCompressedTexImage2D")) |proc| {
        function_pointers.glCompressedTexImage2D = @as(@TypeOf(function_pointers.glCompressedTexImage2D), @ptrCast(proc));
    } else {
        log.err("entry point glCompressedTexImage2D not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glCompressedTexImage1D")) |proc| {
        function_pointers.glCompressedTexImage1D = @as(@TypeOf(function_pointers.glCompressedTexImage1D), @ptrCast(proc));
    } else {
        log.err("entry point glCompressedTexImage1D not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glCompressedTexSubImage3D")) |proc| {
        function_pointers.glCompressedTexSubImage3D = @as(@TypeOf(function_pointers.glCompressedTexSubImage3D), @ptrCast(proc));
    } else {
        log.err("entry point glCompressedTexSubImage3D not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glCompressedTexSubImage2D")) |proc| {
        function_pointers.glCompressedTexSubImage2D = @as(@TypeOf(function_pointers.glCompressedTexSubImage2D), @ptrCast(proc));
    } else {
        log.err("entry point glCompressedTexSubImage2D not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glCompressedTexSubImage1D")) |proc| {
        function_pointers.glCompressedTexSubImage1D = @as(@TypeOf(function_pointers.glCompressedTexSubImage1D), @ptrCast(proc));
    } else {
        log.err("entry point glCompressedTexSubImage1D not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetCompressedTexImage")) |proc| {
        function_pointers.glGetCompressedTexImage = @as(@TypeOf(function_pointers.glGetCompressedTexImage), @ptrCast(proc));
    } else {
        log.err("entry point glGetCompressedTexImage not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttribP4uiv")) |proc| {
        function_pointers.glVertexAttribP4uiv = @as(@TypeOf(function_pointers.glVertexAttribP4uiv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttribP4uiv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttribP4ui")) |proc| {
        function_pointers.glVertexAttribP4ui = @as(@TypeOf(function_pointers.glVertexAttribP4ui), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttribP4ui not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttribP3uiv")) |proc| {
        function_pointers.glVertexAttribP3uiv = @as(@TypeOf(function_pointers.glVertexAttribP3uiv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttribP3uiv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttribP3ui")) |proc| {
        function_pointers.glVertexAttribP3ui = @as(@TypeOf(function_pointers.glVertexAttribP3ui), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttribP3ui not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttribP2uiv")) |proc| {
        function_pointers.glVertexAttribP2uiv = @as(@TypeOf(function_pointers.glVertexAttribP2uiv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttribP2uiv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttribP2ui")) |proc| {
        function_pointers.glVertexAttribP2ui = @as(@TypeOf(function_pointers.glVertexAttribP2ui), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttribP2ui not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttribP1uiv")) |proc| {
        function_pointers.glVertexAttribP1uiv = @as(@TypeOf(function_pointers.glVertexAttribP1uiv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttribP1uiv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttribP1ui")) |proc| {
        function_pointers.glVertexAttribP1ui = @as(@TypeOf(function_pointers.glVertexAttribP1ui), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttribP1ui not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttribDivisor")) |proc| {
        function_pointers.glVertexAttribDivisor = @as(@TypeOf(function_pointers.glVertexAttribDivisor), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttribDivisor not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetQueryObjectui64v")) |proc| {
        function_pointers.glGetQueryObjectui64v = @as(@TypeOf(function_pointers.glGetQueryObjectui64v), @ptrCast(proc));
    } else {
        log.err("entry point glGetQueryObjectui64v not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetQueryObjecti64v")) |proc| {
        function_pointers.glGetQueryObjecti64v = @as(@TypeOf(function_pointers.glGetQueryObjecti64v), @ptrCast(proc));
    } else {
        log.err("entry point glGetQueryObjecti64v not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glQueryCounter")) |proc| {
        function_pointers.glQueryCounter = @as(@TypeOf(function_pointers.glQueryCounter), @ptrCast(proc));
    } else {
        log.err("entry point glQueryCounter not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetSamplerParameterIuiv")) |proc| {
        function_pointers.glGetSamplerParameterIuiv = @as(@TypeOf(function_pointers.glGetSamplerParameterIuiv), @ptrCast(proc));
    } else {
        log.err("entry point glGetSamplerParameterIuiv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetSamplerParameterfv")) |proc| {
        function_pointers.glGetSamplerParameterfv = @as(@TypeOf(function_pointers.glGetSamplerParameterfv), @ptrCast(proc));
    } else {
        log.err("entry point glGetSamplerParameterfv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetSamplerParameterIiv")) |proc| {
        function_pointers.glGetSamplerParameterIiv = @as(@TypeOf(function_pointers.glGetSamplerParameterIiv), @ptrCast(proc));
    } else {
        log.err("entry point glGetSamplerParameterIiv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetSamplerParameteriv")) |proc| {
        function_pointers.glGetSamplerParameteriv = @as(@TypeOf(function_pointers.glGetSamplerParameteriv), @ptrCast(proc));
    } else {
        log.err("entry point glGetSamplerParameteriv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glSamplerParameterIuiv")) |proc| {
        function_pointers.glSamplerParameterIuiv = @as(@TypeOf(function_pointers.glSamplerParameterIuiv), @ptrCast(proc));
    } else {
        log.err("entry point glSamplerParameterIuiv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glSamplerParameterIiv")) |proc| {
        function_pointers.glSamplerParameterIiv = @as(@TypeOf(function_pointers.glSamplerParameterIiv), @ptrCast(proc));
    } else {
        log.err("entry point glSamplerParameterIiv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glSamplerParameterfv")) |proc| {
        function_pointers.glSamplerParameterfv = @as(@TypeOf(function_pointers.glSamplerParameterfv), @ptrCast(proc));
    } else {
        log.err("entry point glSamplerParameterfv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glSamplerParameterf")) |proc| {
        function_pointers.glSamplerParameterf = @as(@TypeOf(function_pointers.glSamplerParameterf), @ptrCast(proc));
    } else {
        log.err("entry point glSamplerParameterf not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glSamplerParameteriv")) |proc| {
        function_pointers.glSamplerParameteriv = @as(@TypeOf(function_pointers.glSamplerParameteriv), @ptrCast(proc));
    } else {
        log.err("entry point glSamplerParameteriv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glSamplerParameteri")) |proc| {
        function_pointers.glSamplerParameteri = @as(@TypeOf(function_pointers.glSamplerParameteri), @ptrCast(proc));
    } else {
        log.err("entry point glSamplerParameteri not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glBindSampler")) |proc| {
        function_pointers.glBindSampler = @as(@TypeOf(function_pointers.glBindSampler), @ptrCast(proc));
    } else {
        log.err("entry point glBindSampler not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glIsSampler")) |proc| {
        function_pointers.glIsSampler = @as(@TypeOf(function_pointers.glIsSampler), @ptrCast(proc));
    } else {
        log.err("entry point glIsSampler not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glDeleteSamplers")) |proc| {
        function_pointers.glDeleteSamplers = @as(@TypeOf(function_pointers.glDeleteSamplers), @ptrCast(proc));
    } else {
        log.err("entry point glDeleteSamplers not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGenSamplers")) |proc| {
        function_pointers.glGenSamplers = @as(@TypeOf(function_pointers.glGenSamplers), @ptrCast(proc));
    } else {
        log.err("entry point glGenSamplers not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetFragDataIndex")) |proc| {
        function_pointers.glGetFragDataIndex = @as(@TypeOf(function_pointers.glGetFragDataIndex), @ptrCast(proc));
    } else {
        log.err("entry point glGetFragDataIndex not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glBindFragDataLocationIndexed")) |proc| {
        function_pointers.glBindFragDataLocationIndexed = @as(@TypeOf(function_pointers.glBindFragDataLocationIndexed), @ptrCast(proc));
    } else {
        log.err("entry point glBindFragDataLocationIndexed not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glSampleMaski")) |proc| {
        function_pointers.glSampleMaski = @as(@TypeOf(function_pointers.glSampleMaski), @ptrCast(proc));
    } else {
        log.err("entry point glSampleMaski not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetMultisamplefv")) |proc| {
        function_pointers.glGetMultisamplefv = @as(@TypeOf(function_pointers.glGetMultisamplefv), @ptrCast(proc));
    } else {
        log.err("entry point glGetMultisamplefv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glTexImage3DMultisample")) |proc| {
        function_pointers.glTexImage3DMultisample = @as(@TypeOf(function_pointers.glTexImage3DMultisample), @ptrCast(proc));
    } else {
        log.err("entry point glTexImage3DMultisample not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glTexImage2DMultisample")) |proc| {
        function_pointers.glTexImage2DMultisample = @as(@TypeOf(function_pointers.glTexImage2DMultisample), @ptrCast(proc));
    } else {
        log.err("entry point glTexImage2DMultisample not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glFramebufferTexture")) |proc| {
        function_pointers.glFramebufferTexture = @as(@TypeOf(function_pointers.glFramebufferTexture), @ptrCast(proc));
    } else {
        log.err("entry point glFramebufferTexture not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetBufferParameteri64v")) |proc| {
        function_pointers.glGetBufferParameteri64v = @as(@TypeOf(function_pointers.glGetBufferParameteri64v), @ptrCast(proc));
    } else {
        log.err("entry point glGetBufferParameteri64v not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glBlendFuncSeparate")) |proc| {
        function_pointers.glBlendFuncSeparate = @as(@TypeOf(function_pointers.glBlendFuncSeparate), @ptrCast(proc));
    } else {
        log.err("entry point glBlendFuncSeparate not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glMultiDrawArrays")) |proc| {
        function_pointers.glMultiDrawArrays = @as(@TypeOf(function_pointers.glMultiDrawArrays), @ptrCast(proc));
    } else {
        log.err("entry point glMultiDrawArrays not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glMultiDrawElements")) |proc| {
        function_pointers.glMultiDrawElements = @as(@TypeOf(function_pointers.glMultiDrawElements), @ptrCast(proc));
    } else {
        log.err("entry point glMultiDrawElements not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glPointParameterf")) |proc| {
        function_pointers.glPointParameterf = @as(@TypeOf(function_pointers.glPointParameterf), @ptrCast(proc));
    } else {
        log.err("entry point glPointParameterf not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glPointParameterfv")) |proc| {
        function_pointers.glPointParameterfv = @as(@TypeOf(function_pointers.glPointParameterfv), @ptrCast(proc));
    } else {
        log.err("entry point glPointParameterfv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glPointParameteri")) |proc| {
        function_pointers.glPointParameteri = @as(@TypeOf(function_pointers.glPointParameteri), @ptrCast(proc));
    } else {
        log.err("entry point glPointParameteri not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glPointParameteriv")) |proc| {
        function_pointers.glPointParameteriv = @as(@TypeOf(function_pointers.glPointParameteriv), @ptrCast(proc));
    } else {
        log.err("entry point glPointParameteriv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetInteger64i_v")) |proc| {
        function_pointers.glGetInteger64i_v = @as(@TypeOf(function_pointers.glGetInteger64i_v), @ptrCast(proc));
    } else {
        log.err("entry point glGetInteger64i_v not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetSynciv")) |proc| {
        function_pointers.glGetSynciv = @as(@TypeOf(function_pointers.glGetSynciv), @ptrCast(proc));
    } else {
        log.err("entry point glGetSynciv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetInteger64v")) |proc| {
        function_pointers.glGetInteger64v = @as(@TypeOf(function_pointers.glGetInteger64v), @ptrCast(proc));
    } else {
        log.err("entry point glGetInteger64v not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glWaitSync")) |proc| {
        function_pointers.glWaitSync = @as(@TypeOf(function_pointers.glWaitSync), @ptrCast(proc));
    } else {
        log.err("entry point glWaitSync not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glClientWaitSync")) |proc| {
        function_pointers.glClientWaitSync = @as(@TypeOf(function_pointers.glClientWaitSync), @ptrCast(proc));
    } else {
        log.err("entry point glClientWaitSync not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glDeleteSync")) |proc| {
        function_pointers.glDeleteSync = @as(@TypeOf(function_pointers.glDeleteSync), @ptrCast(proc));
    } else {
        log.err("entry point glDeleteSync not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glIsSync")) |proc| {
        function_pointers.glIsSync = @as(@TypeOf(function_pointers.glIsSync), @ptrCast(proc));
    } else {
        log.err("entry point glIsSync not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glFenceSync")) |proc| {
        function_pointers.glFenceSync = @as(@TypeOf(function_pointers.glFenceSync), @ptrCast(proc));
    } else {
        log.err("entry point glFenceSync not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glBlendColor")) |proc| {
        function_pointers.glBlendColor = @as(@TypeOf(function_pointers.glBlendColor), @ptrCast(proc));
    } else {
        log.err("entry point glBlendColor not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glBlendEquation")) |proc| {
        function_pointers.glBlendEquation = @as(@TypeOf(function_pointers.glBlendEquation), @ptrCast(proc));
    } else {
        log.err("entry point glBlendEquation not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glProvokingVertex")) |proc| {
        function_pointers.glProvokingVertex = @as(@TypeOf(function_pointers.glProvokingVertex), @ptrCast(proc));
    } else {
        log.err("entry point glProvokingVertex not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glMultiDrawElementsBaseVertex")) |proc| {
        function_pointers.glMultiDrawElementsBaseVertex = @as(@TypeOf(function_pointers.glMultiDrawElementsBaseVertex), @ptrCast(proc));
    } else {
        log.err("entry point glMultiDrawElementsBaseVertex not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glDrawElementsInstancedBaseVertex")) |proc| {
        function_pointers.glDrawElementsInstancedBaseVertex = @as(@TypeOf(function_pointers.glDrawElementsInstancedBaseVertex), @ptrCast(proc));
    } else {
        log.err("entry point glDrawElementsInstancedBaseVertex not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glDrawRangeElementsBaseVertex")) |proc| {
        function_pointers.glDrawRangeElementsBaseVertex = @as(@TypeOf(function_pointers.glDrawRangeElementsBaseVertex), @ptrCast(proc));
    } else {
        log.err("entry point glDrawRangeElementsBaseVertex not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glDrawElementsBaseVertex")) |proc| {
        function_pointers.glDrawElementsBaseVertex = @as(@TypeOf(function_pointers.glDrawElementsBaseVertex), @ptrCast(proc));
    } else {
        log.err("entry point glDrawElementsBaseVertex not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGenQueries")) |proc| {
        function_pointers.glGenQueries = @as(@TypeOf(function_pointers.glGenQueries), @ptrCast(proc));
    } else {
        log.err("entry point glGenQueries not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glDeleteQueries")) |proc| {
        function_pointers.glDeleteQueries = @as(@TypeOf(function_pointers.glDeleteQueries), @ptrCast(proc));
    } else {
        log.err("entry point glDeleteQueries not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glIsQuery")) |proc| {
        function_pointers.glIsQuery = @as(@TypeOf(function_pointers.glIsQuery), @ptrCast(proc));
    } else {
        log.err("entry point glIsQuery not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glBeginQuery")) |proc| {
        function_pointers.glBeginQuery = @as(@TypeOf(function_pointers.glBeginQuery), @ptrCast(proc));
    } else {
        log.err("entry point glBeginQuery not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glEndQuery")) |proc| {
        function_pointers.glEndQuery = @as(@TypeOf(function_pointers.glEndQuery), @ptrCast(proc));
    } else {
        log.err("entry point glEndQuery not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetQueryiv")) |proc| {
        function_pointers.glGetQueryiv = @as(@TypeOf(function_pointers.glGetQueryiv), @ptrCast(proc));
    } else {
        log.err("entry point glGetQueryiv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetQueryObjectiv")) |proc| {
        function_pointers.glGetQueryObjectiv = @as(@TypeOf(function_pointers.glGetQueryObjectiv), @ptrCast(proc));
    } else {
        log.err("entry point glGetQueryObjectiv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetQueryObjectuiv")) |proc| {
        function_pointers.glGetQueryObjectuiv = @as(@TypeOf(function_pointers.glGetQueryObjectuiv), @ptrCast(proc));
    } else {
        log.err("entry point glGetQueryObjectuiv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glBindBuffer")) |proc| {
        function_pointers.glBindBuffer = @as(@TypeOf(function_pointers.glBindBuffer), @ptrCast(proc));
    } else {
        log.err("entry point glBindBuffer not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glDeleteBuffers")) |proc| {
        function_pointers.glDeleteBuffers = @as(@TypeOf(function_pointers.glDeleteBuffers), @ptrCast(proc));
    } else {
        log.err("entry point glDeleteBuffers not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGenBuffers")) |proc| {
        function_pointers.glGenBuffers = @as(@TypeOf(function_pointers.glGenBuffers), @ptrCast(proc));
    } else {
        log.err("entry point glGenBuffers not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glIsBuffer")) |proc| {
        function_pointers.glIsBuffer = @as(@TypeOf(function_pointers.glIsBuffer), @ptrCast(proc));
    } else {
        log.err("entry point glIsBuffer not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glBufferData")) |proc| {
        function_pointers.glBufferData = @as(@TypeOf(function_pointers.glBufferData), @ptrCast(proc));
    } else {
        log.err("entry point glBufferData not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glBufferSubData")) |proc| {
        function_pointers.glBufferSubData = @as(@TypeOf(function_pointers.glBufferSubData), @ptrCast(proc));
    } else {
        log.err("entry point glBufferSubData not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetBufferSubData")) |proc| {
        function_pointers.glGetBufferSubData = @as(@TypeOf(function_pointers.glGetBufferSubData), @ptrCast(proc));
    } else {
        log.err("entry point glGetBufferSubData not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glMapBuffer")) |proc| {
        function_pointers.glMapBuffer = @as(@TypeOf(function_pointers.glMapBuffer), @ptrCast(proc));
    } else {
        log.err("entry point glMapBuffer not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glUnmapBuffer")) |proc| {
        function_pointers.glUnmapBuffer = @as(@TypeOf(function_pointers.glUnmapBuffer), @ptrCast(proc));
    } else {
        log.err("entry point glUnmapBuffer not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetBufferParameteriv")) |proc| {
        function_pointers.glGetBufferParameteriv = @as(@TypeOf(function_pointers.glGetBufferParameteriv), @ptrCast(proc));
    } else {
        log.err("entry point glGetBufferParameteriv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetBufferPointerv")) |proc| {
        function_pointers.glGetBufferPointerv = @as(@TypeOf(function_pointers.glGetBufferPointerv), @ptrCast(proc));
    } else {
        log.err("entry point glGetBufferPointerv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glBlendEquationSeparate")) |proc| {
        function_pointers.glBlendEquationSeparate = @as(@TypeOf(function_pointers.glBlendEquationSeparate), @ptrCast(proc));
    } else {
        log.err("entry point glBlendEquationSeparate not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glDrawBuffers")) |proc| {
        function_pointers.glDrawBuffers = @as(@TypeOf(function_pointers.glDrawBuffers), @ptrCast(proc));
    } else {
        log.err("entry point glDrawBuffers not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glStencilOpSeparate")) |proc| {
        function_pointers.glStencilOpSeparate = @as(@TypeOf(function_pointers.glStencilOpSeparate), @ptrCast(proc));
    } else {
        log.err("entry point glStencilOpSeparate not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glStencilFuncSeparate")) |proc| {
        function_pointers.glStencilFuncSeparate = @as(@TypeOf(function_pointers.glStencilFuncSeparate), @ptrCast(proc));
    } else {
        log.err("entry point glStencilFuncSeparate not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glStencilMaskSeparate")) |proc| {
        function_pointers.glStencilMaskSeparate = @as(@TypeOf(function_pointers.glStencilMaskSeparate), @ptrCast(proc));
    } else {
        log.err("entry point glStencilMaskSeparate not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glAttachShader")) |proc| {
        function_pointers.glAttachShader = @as(@TypeOf(function_pointers.glAttachShader), @ptrCast(proc));
    } else {
        log.err("entry point glAttachShader not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glBindAttribLocation")) |proc| {
        function_pointers.glBindAttribLocation = @as(@TypeOf(function_pointers.glBindAttribLocation), @ptrCast(proc));
    } else {
        log.err("entry point glBindAttribLocation not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glCompileShader")) |proc| {
        function_pointers.glCompileShader = @as(@TypeOf(function_pointers.glCompileShader), @ptrCast(proc));
    } else {
        log.err("entry point glCompileShader not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glCreateProgram")) |proc| {
        function_pointers.glCreateProgram = @as(@TypeOf(function_pointers.glCreateProgram), @ptrCast(proc));
    } else {
        log.err("entry point glCreateProgram not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glCreateShader")) |proc| {
        function_pointers.glCreateShader = @as(@TypeOf(function_pointers.glCreateShader), @ptrCast(proc));
    } else {
        log.err("entry point glCreateShader not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glDeleteProgram")) |proc| {
        function_pointers.glDeleteProgram = @as(@TypeOf(function_pointers.glDeleteProgram), @ptrCast(proc));
    } else {
        log.err("entry point glDeleteProgram not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glDeleteShader")) |proc| {
        function_pointers.glDeleteShader = @as(@TypeOf(function_pointers.glDeleteShader), @ptrCast(proc));
    } else {
        log.err("entry point glDeleteShader not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glDetachShader")) |proc| {
        function_pointers.glDetachShader = @as(@TypeOf(function_pointers.glDetachShader), @ptrCast(proc));
    } else {
        log.err("entry point glDetachShader not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glDisableVertexAttribArray")) |proc| {
        function_pointers.glDisableVertexAttribArray = @as(@TypeOf(function_pointers.glDisableVertexAttribArray), @ptrCast(proc));
    } else {
        log.err("entry point glDisableVertexAttribArray not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glEnableVertexAttribArray")) |proc| {
        function_pointers.glEnableVertexAttribArray = @as(@TypeOf(function_pointers.glEnableVertexAttribArray), @ptrCast(proc));
    } else {
        log.err("entry point glEnableVertexAttribArray not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetActiveAttrib")) |proc| {
        function_pointers.glGetActiveAttrib = @as(@TypeOf(function_pointers.glGetActiveAttrib), @ptrCast(proc));
    } else {
        log.err("entry point glGetActiveAttrib not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetActiveUniform")) |proc| {
        function_pointers.glGetActiveUniform = @as(@TypeOf(function_pointers.glGetActiveUniform), @ptrCast(proc));
    } else {
        log.err("entry point glGetActiveUniform not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetAttachedShaders")) |proc| {
        function_pointers.glGetAttachedShaders = @as(@TypeOf(function_pointers.glGetAttachedShaders), @ptrCast(proc));
    } else {
        log.err("entry point glGetAttachedShaders not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetAttribLocation")) |proc| {
        function_pointers.glGetAttribLocation = @as(@TypeOf(function_pointers.glGetAttribLocation), @ptrCast(proc));
    } else {
        log.err("entry point glGetAttribLocation not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetProgramiv")) |proc| {
        function_pointers.glGetProgramiv = @as(@TypeOf(function_pointers.glGetProgramiv), @ptrCast(proc));
    } else {
        log.err("entry point glGetProgramiv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetProgramInfoLog")) |proc| {
        function_pointers.glGetProgramInfoLog = @as(@TypeOf(function_pointers.glGetProgramInfoLog), @ptrCast(proc));
    } else {
        log.err("entry point glGetProgramInfoLog not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetShaderiv")) |proc| {
        function_pointers.glGetShaderiv = @as(@TypeOf(function_pointers.glGetShaderiv), @ptrCast(proc));
    } else {
        log.err("entry point glGetShaderiv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetShaderInfoLog")) |proc| {
        function_pointers.glGetShaderInfoLog = @as(@TypeOf(function_pointers.glGetShaderInfoLog), @ptrCast(proc));
    } else {
        log.err("entry point glGetShaderInfoLog not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetShaderSource")) |proc| {
        function_pointers.glGetShaderSource = @as(@TypeOf(function_pointers.glGetShaderSource), @ptrCast(proc));
    } else {
        log.err("entry point glGetShaderSource not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetUniformLocation")) |proc| {
        function_pointers.glGetUniformLocation = @as(@TypeOf(function_pointers.glGetUniformLocation), @ptrCast(proc));
    } else {
        log.err("entry point glGetUniformLocation not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetUniformfv")) |proc| {
        function_pointers.glGetUniformfv = @as(@TypeOf(function_pointers.glGetUniformfv), @ptrCast(proc));
    } else {
        log.err("entry point glGetUniformfv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetUniformiv")) |proc| {
        function_pointers.glGetUniformiv = @as(@TypeOf(function_pointers.glGetUniformiv), @ptrCast(proc));
    } else {
        log.err("entry point glGetUniformiv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetVertexAttribdv")) |proc| {
        function_pointers.glGetVertexAttribdv = @as(@TypeOf(function_pointers.glGetVertexAttribdv), @ptrCast(proc));
    } else {
        log.err("entry point glGetVertexAttribdv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetVertexAttribfv")) |proc| {
        function_pointers.glGetVertexAttribfv = @as(@TypeOf(function_pointers.glGetVertexAttribfv), @ptrCast(proc));
    } else {
        log.err("entry point glGetVertexAttribfv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetVertexAttribiv")) |proc| {
        function_pointers.glGetVertexAttribiv = @as(@TypeOf(function_pointers.glGetVertexAttribiv), @ptrCast(proc));
    } else {
        log.err("entry point glGetVertexAttribiv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetVertexAttribPointerv")) |proc| {
        function_pointers.glGetVertexAttribPointerv = @as(@TypeOf(function_pointers.glGetVertexAttribPointerv), @ptrCast(proc));
    } else {
        log.err("entry point glGetVertexAttribPointerv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glIsProgram")) |proc| {
        function_pointers.glIsProgram = @as(@TypeOf(function_pointers.glIsProgram), @ptrCast(proc));
    } else {
        log.err("entry point glIsProgram not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glIsShader")) |proc| {
        function_pointers.glIsShader = @as(@TypeOf(function_pointers.glIsShader), @ptrCast(proc));
    } else {
        log.err("entry point glIsShader not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glLinkProgram")) |proc| {
        function_pointers.glLinkProgram = @as(@TypeOf(function_pointers.glLinkProgram), @ptrCast(proc));
    } else {
        log.err("entry point glLinkProgram not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glShaderSource")) |proc| {
        function_pointers.glShaderSource = @as(@TypeOf(function_pointers.glShaderSource), @ptrCast(proc));
    } else {
        log.err("entry point glShaderSource not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glUseProgram")) |proc| {
        function_pointers.glUseProgram = @as(@TypeOf(function_pointers.glUseProgram), @ptrCast(proc));
    } else {
        log.err("entry point glUseProgram not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glUniform1f")) |proc| {
        function_pointers.glUniform1f = @as(@TypeOf(function_pointers.glUniform1f), @ptrCast(proc));
    } else {
        log.err("entry point glUniform1f not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glUniform2f")) |proc| {
        function_pointers.glUniform2f = @as(@TypeOf(function_pointers.glUniform2f), @ptrCast(proc));
    } else {
        log.err("entry point glUniform2f not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glUniform3f")) |proc| {
        function_pointers.glUniform3f = @as(@TypeOf(function_pointers.glUniform3f), @ptrCast(proc));
    } else {
        log.err("entry point glUniform3f not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glUniform4f")) |proc| {
        function_pointers.glUniform4f = @as(@TypeOf(function_pointers.glUniform4f), @ptrCast(proc));
    } else {
        log.err("entry point glUniform4f not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glUniform1i")) |proc| {
        function_pointers.glUniform1i = @as(@TypeOf(function_pointers.glUniform1i), @ptrCast(proc));
    } else {
        log.err("entry point glUniform1i not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glUniform2i")) |proc| {
        function_pointers.glUniform2i = @as(@TypeOf(function_pointers.glUniform2i), @ptrCast(proc));
    } else {
        log.err("entry point glUniform2i not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glUniform3i")) |proc| {
        function_pointers.glUniform3i = @as(@TypeOf(function_pointers.glUniform3i), @ptrCast(proc));
    } else {
        log.err("entry point glUniform3i not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glUniform4i")) |proc| {
        function_pointers.glUniform4i = @as(@TypeOf(function_pointers.glUniform4i), @ptrCast(proc));
    } else {
        log.err("entry point glUniform4i not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glUniform1fv")) |proc| {
        function_pointers.glUniform1fv = @as(@TypeOf(function_pointers.glUniform1fv), @ptrCast(proc));
    } else {
        log.err("entry point glUniform1fv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glUniform2fv")) |proc| {
        function_pointers.glUniform2fv = @as(@TypeOf(function_pointers.glUniform2fv), @ptrCast(proc));
    } else {
        log.err("entry point glUniform2fv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glUniform3fv")) |proc| {
        function_pointers.glUniform3fv = @as(@TypeOf(function_pointers.glUniform3fv), @ptrCast(proc));
    } else {
        log.err("entry point glUniform3fv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glUniform4fv")) |proc| {
        function_pointers.glUniform4fv = @as(@TypeOf(function_pointers.glUniform4fv), @ptrCast(proc));
    } else {
        log.err("entry point glUniform4fv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glUniform1iv")) |proc| {
        function_pointers.glUniform1iv = @as(@TypeOf(function_pointers.glUniform1iv), @ptrCast(proc));
    } else {
        log.err("entry point glUniform1iv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glUniform2iv")) |proc| {
        function_pointers.glUniform2iv = @as(@TypeOf(function_pointers.glUniform2iv), @ptrCast(proc));
    } else {
        log.err("entry point glUniform2iv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glUniform3iv")) |proc| {
        function_pointers.glUniform3iv = @as(@TypeOf(function_pointers.glUniform3iv), @ptrCast(proc));
    } else {
        log.err("entry point glUniform3iv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glUniform4iv")) |proc| {
        function_pointers.glUniform4iv = @as(@TypeOf(function_pointers.glUniform4iv), @ptrCast(proc));
    } else {
        log.err("entry point glUniform4iv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glUniformMatrix2fv")) |proc| {
        function_pointers.glUniformMatrix2fv = @as(@TypeOf(function_pointers.glUniformMatrix2fv), @ptrCast(proc));
    } else {
        log.err("entry point glUniformMatrix2fv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glUniformMatrix3fv")) |proc| {
        function_pointers.glUniformMatrix3fv = @as(@TypeOf(function_pointers.glUniformMatrix3fv), @ptrCast(proc));
    } else {
        log.err("entry point glUniformMatrix3fv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glUniformMatrix4fv")) |proc| {
        function_pointers.glUniformMatrix4fv = @as(@TypeOf(function_pointers.glUniformMatrix4fv), @ptrCast(proc));
    } else {
        log.err("entry point glUniformMatrix4fv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glValidateProgram")) |proc| {
        function_pointers.glValidateProgram = @as(@TypeOf(function_pointers.glValidateProgram), @ptrCast(proc));
    } else {
        log.err("entry point glValidateProgram not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttrib1d")) |proc| {
        function_pointers.glVertexAttrib1d = @as(@TypeOf(function_pointers.glVertexAttrib1d), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttrib1d not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttrib1dv")) |proc| {
        function_pointers.glVertexAttrib1dv = @as(@TypeOf(function_pointers.glVertexAttrib1dv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttrib1dv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttrib1f")) |proc| {
        function_pointers.glVertexAttrib1f = @as(@TypeOf(function_pointers.glVertexAttrib1f), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttrib1f not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttrib1fv")) |proc| {
        function_pointers.glVertexAttrib1fv = @as(@TypeOf(function_pointers.glVertexAttrib1fv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttrib1fv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttrib1s")) |proc| {
        function_pointers.glVertexAttrib1s = @as(@TypeOf(function_pointers.glVertexAttrib1s), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttrib1s not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttrib1sv")) |proc| {
        function_pointers.glVertexAttrib1sv = @as(@TypeOf(function_pointers.glVertexAttrib1sv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttrib1sv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttrib2d")) |proc| {
        function_pointers.glVertexAttrib2d = @as(@TypeOf(function_pointers.glVertexAttrib2d), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttrib2d not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttrib2dv")) |proc| {
        function_pointers.glVertexAttrib2dv = @as(@TypeOf(function_pointers.glVertexAttrib2dv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttrib2dv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttrib2f")) |proc| {
        function_pointers.glVertexAttrib2f = @as(@TypeOf(function_pointers.glVertexAttrib2f), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttrib2f not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttrib2fv")) |proc| {
        function_pointers.glVertexAttrib2fv = @as(@TypeOf(function_pointers.glVertexAttrib2fv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttrib2fv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttrib2s")) |proc| {
        function_pointers.glVertexAttrib2s = @as(@TypeOf(function_pointers.glVertexAttrib2s), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttrib2s not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttrib2sv")) |proc| {
        function_pointers.glVertexAttrib2sv = @as(@TypeOf(function_pointers.glVertexAttrib2sv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttrib2sv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttrib3d")) |proc| {
        function_pointers.glVertexAttrib3d = @as(@TypeOf(function_pointers.glVertexAttrib3d), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttrib3d not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttrib3dv")) |proc| {
        function_pointers.glVertexAttrib3dv = @as(@TypeOf(function_pointers.glVertexAttrib3dv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttrib3dv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttrib3f")) |proc| {
        function_pointers.glVertexAttrib3f = @as(@TypeOf(function_pointers.glVertexAttrib3f), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttrib3f not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttrib3fv")) |proc| {
        function_pointers.glVertexAttrib3fv = @as(@TypeOf(function_pointers.glVertexAttrib3fv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttrib3fv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttrib3s")) |proc| {
        function_pointers.glVertexAttrib3s = @as(@TypeOf(function_pointers.glVertexAttrib3s), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttrib3s not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttrib3sv")) |proc| {
        function_pointers.glVertexAttrib3sv = @as(@TypeOf(function_pointers.glVertexAttrib3sv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttrib3sv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttrib4Nbv")) |proc| {
        function_pointers.glVertexAttrib4Nbv = @as(@TypeOf(function_pointers.glVertexAttrib4Nbv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttrib4Nbv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttrib4Niv")) |proc| {
        function_pointers.glVertexAttrib4Niv = @as(@TypeOf(function_pointers.glVertexAttrib4Niv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttrib4Niv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttrib4Nsv")) |proc| {
        function_pointers.glVertexAttrib4Nsv = @as(@TypeOf(function_pointers.glVertexAttrib4Nsv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttrib4Nsv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttrib4Nub")) |proc| {
        function_pointers.glVertexAttrib4Nub = @as(@TypeOf(function_pointers.glVertexAttrib4Nub), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttrib4Nub not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttrib4Nubv")) |proc| {
        function_pointers.glVertexAttrib4Nubv = @as(@TypeOf(function_pointers.glVertexAttrib4Nubv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttrib4Nubv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttrib4Nuiv")) |proc| {
        function_pointers.glVertexAttrib4Nuiv = @as(@TypeOf(function_pointers.glVertexAttrib4Nuiv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttrib4Nuiv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttrib4Nusv")) |proc| {
        function_pointers.glVertexAttrib4Nusv = @as(@TypeOf(function_pointers.glVertexAttrib4Nusv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttrib4Nusv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttrib4bv")) |proc| {
        function_pointers.glVertexAttrib4bv = @as(@TypeOf(function_pointers.glVertexAttrib4bv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttrib4bv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttrib4d")) |proc| {
        function_pointers.glVertexAttrib4d = @as(@TypeOf(function_pointers.glVertexAttrib4d), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttrib4d not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttrib4dv")) |proc| {
        function_pointers.glVertexAttrib4dv = @as(@TypeOf(function_pointers.glVertexAttrib4dv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttrib4dv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttrib4f")) |proc| {
        function_pointers.glVertexAttrib4f = @as(@TypeOf(function_pointers.glVertexAttrib4f), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttrib4f not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttrib4fv")) |proc| {
        function_pointers.glVertexAttrib4fv = @as(@TypeOf(function_pointers.glVertexAttrib4fv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttrib4fv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttrib4iv")) |proc| {
        function_pointers.glVertexAttrib4iv = @as(@TypeOf(function_pointers.glVertexAttrib4iv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttrib4iv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttrib4s")) |proc| {
        function_pointers.glVertexAttrib4s = @as(@TypeOf(function_pointers.glVertexAttrib4s), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttrib4s not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttrib4sv")) |proc| {
        function_pointers.glVertexAttrib4sv = @as(@TypeOf(function_pointers.glVertexAttrib4sv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttrib4sv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttrib4ubv")) |proc| {
        function_pointers.glVertexAttrib4ubv = @as(@TypeOf(function_pointers.glVertexAttrib4ubv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttrib4ubv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttrib4uiv")) |proc| {
        function_pointers.glVertexAttrib4uiv = @as(@TypeOf(function_pointers.glVertexAttrib4uiv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttrib4uiv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttrib4usv")) |proc| {
        function_pointers.glVertexAttrib4usv = @as(@TypeOf(function_pointers.glVertexAttrib4usv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttrib4usv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttribPointer")) |proc| {
        function_pointers.glVertexAttribPointer = @as(@TypeOf(function_pointers.glVertexAttribPointer), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttribPointer not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glUniformMatrix2x3fv")) |proc| {
        function_pointers.glUniformMatrix2x3fv = @as(@TypeOf(function_pointers.glUniformMatrix2x3fv), @ptrCast(proc));
    } else {
        log.err("entry point glUniformMatrix2x3fv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glUniformMatrix3x2fv")) |proc| {
        function_pointers.glUniformMatrix3x2fv = @as(@TypeOf(function_pointers.glUniformMatrix3x2fv), @ptrCast(proc));
    } else {
        log.err("entry point glUniformMatrix3x2fv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glUniformMatrix2x4fv")) |proc| {
        function_pointers.glUniformMatrix2x4fv = @as(@TypeOf(function_pointers.glUniformMatrix2x4fv), @ptrCast(proc));
    } else {
        log.err("entry point glUniformMatrix2x4fv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glUniformMatrix4x2fv")) |proc| {
        function_pointers.glUniformMatrix4x2fv = @as(@TypeOf(function_pointers.glUniformMatrix4x2fv), @ptrCast(proc));
    } else {
        log.err("entry point glUniformMatrix4x2fv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glUniformMatrix3x4fv")) |proc| {
        function_pointers.glUniformMatrix3x4fv = @as(@TypeOf(function_pointers.glUniformMatrix3x4fv), @ptrCast(proc));
    } else {
        log.err("entry point glUniformMatrix3x4fv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glUniformMatrix4x3fv")) |proc| {
        function_pointers.glUniformMatrix4x3fv = @as(@TypeOf(function_pointers.glUniformMatrix4x3fv), @ptrCast(proc));
    } else {
        log.err("entry point glUniformMatrix4x3fv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glColorMaski")) |proc| {
        function_pointers.glColorMaski = @as(@TypeOf(function_pointers.glColorMaski), @ptrCast(proc));
    } else {
        log.err("entry point glColorMaski not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetBooleani_v")) |proc| {
        function_pointers.glGetBooleani_v = @as(@TypeOf(function_pointers.glGetBooleani_v), @ptrCast(proc));
    } else {
        log.err("entry point glGetBooleani_v not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetIntegeri_v")) |proc| {
        function_pointers.glGetIntegeri_v = @as(@TypeOf(function_pointers.glGetIntegeri_v), @ptrCast(proc));
    } else {
        log.err("entry point glGetIntegeri_v not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glEnablei")) |proc| {
        function_pointers.glEnablei = @as(@TypeOf(function_pointers.glEnablei), @ptrCast(proc));
    } else {
        log.err("entry point glEnablei not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glDisablei")) |proc| {
        function_pointers.glDisablei = @as(@TypeOf(function_pointers.glDisablei), @ptrCast(proc));
    } else {
        log.err("entry point glDisablei not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glIsEnabledi")) |proc| {
        function_pointers.glIsEnabledi = @as(@TypeOf(function_pointers.glIsEnabledi), @ptrCast(proc));
    } else {
        log.err("entry point glIsEnabledi not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glBeginTransformFeedback")) |proc| {
        function_pointers.glBeginTransformFeedback = @as(@TypeOf(function_pointers.glBeginTransformFeedback), @ptrCast(proc));
    } else {
        log.err("entry point glBeginTransformFeedback not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glEndTransformFeedback")) |proc| {
        function_pointers.glEndTransformFeedback = @as(@TypeOf(function_pointers.glEndTransformFeedback), @ptrCast(proc));
    } else {
        log.err("entry point glEndTransformFeedback not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glBindBufferRange")) |proc| {
        function_pointers.glBindBufferRange = @as(@TypeOf(function_pointers.glBindBufferRange), @ptrCast(proc));
    } else {
        log.err("entry point glBindBufferRange not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glBindBufferBase")) |proc| {
        function_pointers.glBindBufferBase = @as(@TypeOf(function_pointers.glBindBufferBase), @ptrCast(proc));
    } else {
        log.err("entry point glBindBufferBase not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glTransformFeedbackVaryings")) |proc| {
        function_pointers.glTransformFeedbackVaryings = @as(@TypeOf(function_pointers.glTransformFeedbackVaryings), @ptrCast(proc));
    } else {
        log.err("entry point glTransformFeedbackVaryings not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetTransformFeedbackVarying")) |proc| {
        function_pointers.glGetTransformFeedbackVarying = @as(@TypeOf(function_pointers.glGetTransformFeedbackVarying), @ptrCast(proc));
    } else {
        log.err("entry point glGetTransformFeedbackVarying not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glClampColor")) |proc| {
        function_pointers.glClampColor = @as(@TypeOf(function_pointers.glClampColor), @ptrCast(proc));
    } else {
        log.err("entry point glClampColor not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glBeginConditionalRender")) |proc| {
        function_pointers.glBeginConditionalRender = @as(@TypeOf(function_pointers.glBeginConditionalRender), @ptrCast(proc));
    } else {
        log.err("entry point glBeginConditionalRender not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glEndConditionalRender")) |proc| {
        function_pointers.glEndConditionalRender = @as(@TypeOf(function_pointers.glEndConditionalRender), @ptrCast(proc));
    } else {
        log.err("entry point glEndConditionalRender not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttribIPointer")) |proc| {
        function_pointers.glVertexAttribIPointer = @as(@TypeOf(function_pointers.glVertexAttribIPointer), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttribIPointer not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetVertexAttribIiv")) |proc| {
        function_pointers.glGetVertexAttribIiv = @as(@TypeOf(function_pointers.glGetVertexAttribIiv), @ptrCast(proc));
    } else {
        log.err("entry point glGetVertexAttribIiv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetVertexAttribIuiv")) |proc| {
        function_pointers.glGetVertexAttribIuiv = @as(@TypeOf(function_pointers.glGetVertexAttribIuiv), @ptrCast(proc));
    } else {
        log.err("entry point glGetVertexAttribIuiv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttribI1i")) |proc| {
        function_pointers.glVertexAttribI1i = @as(@TypeOf(function_pointers.glVertexAttribI1i), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttribI1i not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttribI2i")) |proc| {
        function_pointers.glVertexAttribI2i = @as(@TypeOf(function_pointers.glVertexAttribI2i), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttribI2i not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttribI3i")) |proc| {
        function_pointers.glVertexAttribI3i = @as(@TypeOf(function_pointers.glVertexAttribI3i), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttribI3i not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttribI4i")) |proc| {
        function_pointers.glVertexAttribI4i = @as(@TypeOf(function_pointers.glVertexAttribI4i), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttribI4i not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttribI1ui")) |proc| {
        function_pointers.glVertexAttribI1ui = @as(@TypeOf(function_pointers.glVertexAttribI1ui), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttribI1ui not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttribI2ui")) |proc| {
        function_pointers.glVertexAttribI2ui = @as(@TypeOf(function_pointers.glVertexAttribI2ui), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttribI2ui not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttribI3ui")) |proc| {
        function_pointers.glVertexAttribI3ui = @as(@TypeOf(function_pointers.glVertexAttribI3ui), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttribI3ui not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttribI4ui")) |proc| {
        function_pointers.glVertexAttribI4ui = @as(@TypeOf(function_pointers.glVertexAttribI4ui), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttribI4ui not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttribI1iv")) |proc| {
        function_pointers.glVertexAttribI1iv = @as(@TypeOf(function_pointers.glVertexAttribI1iv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttribI1iv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttribI2iv")) |proc| {
        function_pointers.glVertexAttribI2iv = @as(@TypeOf(function_pointers.glVertexAttribI2iv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttribI2iv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttribI3iv")) |proc| {
        function_pointers.glVertexAttribI3iv = @as(@TypeOf(function_pointers.glVertexAttribI3iv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttribI3iv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttribI4iv")) |proc| {
        function_pointers.glVertexAttribI4iv = @as(@TypeOf(function_pointers.glVertexAttribI4iv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttribI4iv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttribI1uiv")) |proc| {
        function_pointers.glVertexAttribI1uiv = @as(@TypeOf(function_pointers.glVertexAttribI1uiv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttribI1uiv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttribI2uiv")) |proc| {
        function_pointers.glVertexAttribI2uiv = @as(@TypeOf(function_pointers.glVertexAttribI2uiv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttribI2uiv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttribI3uiv")) |proc| {
        function_pointers.glVertexAttribI3uiv = @as(@TypeOf(function_pointers.glVertexAttribI3uiv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttribI3uiv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttribI4uiv")) |proc| {
        function_pointers.glVertexAttribI4uiv = @as(@TypeOf(function_pointers.glVertexAttribI4uiv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttribI4uiv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttribI4bv")) |proc| {
        function_pointers.glVertexAttribI4bv = @as(@TypeOf(function_pointers.glVertexAttribI4bv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttribI4bv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttribI4sv")) |proc| {
        function_pointers.glVertexAttribI4sv = @as(@TypeOf(function_pointers.glVertexAttribI4sv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttribI4sv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttribI4ubv")) |proc| {
        function_pointers.glVertexAttribI4ubv = @as(@TypeOf(function_pointers.glVertexAttribI4ubv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttribI4ubv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glVertexAttribI4usv")) |proc| {
        function_pointers.glVertexAttribI4usv = @as(@TypeOf(function_pointers.glVertexAttribI4usv), @ptrCast(proc));
    } else {
        log.err("entry point glVertexAttribI4usv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetUniformuiv")) |proc| {
        function_pointers.glGetUniformuiv = @as(@TypeOf(function_pointers.glGetUniformuiv), @ptrCast(proc));
    } else {
        log.err("entry point glGetUniformuiv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glBindFragDataLocation")) |proc| {
        function_pointers.glBindFragDataLocation = @as(@TypeOf(function_pointers.glBindFragDataLocation), @ptrCast(proc));
    } else {
        log.err("entry point glBindFragDataLocation not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetFragDataLocation")) |proc| {
        function_pointers.glGetFragDataLocation = @as(@TypeOf(function_pointers.glGetFragDataLocation), @ptrCast(proc));
    } else {
        log.err("entry point glGetFragDataLocation not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glUniform1ui")) |proc| {
        function_pointers.glUniform1ui = @as(@TypeOf(function_pointers.glUniform1ui), @ptrCast(proc));
    } else {
        log.err("entry point glUniform1ui not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glUniform2ui")) |proc| {
        function_pointers.glUniform2ui = @as(@TypeOf(function_pointers.glUniform2ui), @ptrCast(proc));
    } else {
        log.err("entry point glUniform2ui not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glUniform3ui")) |proc| {
        function_pointers.glUniform3ui = @as(@TypeOf(function_pointers.glUniform3ui), @ptrCast(proc));
    } else {
        log.err("entry point glUniform3ui not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glUniform4ui")) |proc| {
        function_pointers.glUniform4ui = @as(@TypeOf(function_pointers.glUniform4ui), @ptrCast(proc));
    } else {
        log.err("entry point glUniform4ui not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glUniform1uiv")) |proc| {
        function_pointers.glUniform1uiv = @as(@TypeOf(function_pointers.glUniform1uiv), @ptrCast(proc));
    } else {
        log.err("entry point glUniform1uiv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glUniform2uiv")) |proc| {
        function_pointers.glUniform2uiv = @as(@TypeOf(function_pointers.glUniform2uiv), @ptrCast(proc));
    } else {
        log.err("entry point glUniform2uiv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glUniform3uiv")) |proc| {
        function_pointers.glUniform3uiv = @as(@TypeOf(function_pointers.glUniform3uiv), @ptrCast(proc));
    } else {
        log.err("entry point glUniform3uiv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glUniform4uiv")) |proc| {
        function_pointers.glUniform4uiv = @as(@TypeOf(function_pointers.glUniform4uiv), @ptrCast(proc));
    } else {
        log.err("entry point glUniform4uiv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glTexParameterIiv")) |proc| {
        function_pointers.glTexParameterIiv = @as(@TypeOf(function_pointers.glTexParameterIiv), @ptrCast(proc));
    } else {
        log.err("entry point glTexParameterIiv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glTexParameterIuiv")) |proc| {
        function_pointers.glTexParameterIuiv = @as(@TypeOf(function_pointers.glTexParameterIuiv), @ptrCast(proc));
    } else {
        log.err("entry point glTexParameterIuiv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetTexParameterIiv")) |proc| {
        function_pointers.glGetTexParameterIiv = @as(@TypeOf(function_pointers.glGetTexParameterIiv), @ptrCast(proc));
    } else {
        log.err("entry point glGetTexParameterIiv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetTexParameterIuiv")) |proc| {
        function_pointers.glGetTexParameterIuiv = @as(@TypeOf(function_pointers.glGetTexParameterIuiv), @ptrCast(proc));
    } else {
        log.err("entry point glGetTexParameterIuiv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glClearBufferiv")) |proc| {
        function_pointers.glClearBufferiv = @as(@TypeOf(function_pointers.glClearBufferiv), @ptrCast(proc));
    } else {
        log.err("entry point glClearBufferiv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glClearBufferuiv")) |proc| {
        function_pointers.glClearBufferuiv = @as(@TypeOf(function_pointers.glClearBufferuiv), @ptrCast(proc));
    } else {
        log.err("entry point glClearBufferuiv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glClearBufferfv")) |proc| {
        function_pointers.glClearBufferfv = @as(@TypeOf(function_pointers.glClearBufferfv), @ptrCast(proc));
    } else {
        log.err("entry point glClearBufferfv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glClearBufferfi")) |proc| {
        function_pointers.glClearBufferfi = @as(@TypeOf(function_pointers.glClearBufferfi), @ptrCast(proc));
    } else {
        log.err("entry point glClearBufferfi not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetStringi")) |proc| {
        function_pointers.glGetStringi = @as(@TypeOf(function_pointers.glGetStringi), @ptrCast(proc));
    } else {
        log.err("entry point glGetStringi not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glIsRenderbuffer")) |proc| {
        function_pointers.glIsRenderbuffer = @as(@TypeOf(function_pointers.glIsRenderbuffer), @ptrCast(proc));
    } else {
        log.err("entry point glIsRenderbuffer not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glBindRenderbuffer")) |proc| {
        function_pointers.glBindRenderbuffer = @as(@TypeOf(function_pointers.glBindRenderbuffer), @ptrCast(proc));
    } else {
        log.err("entry point glBindRenderbuffer not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glDeleteRenderbuffers")) |proc| {
        function_pointers.glDeleteRenderbuffers = @as(@TypeOf(function_pointers.glDeleteRenderbuffers), @ptrCast(proc));
    } else {
        log.err("entry point glDeleteRenderbuffers not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGenRenderbuffers")) |proc| {
        function_pointers.glGenRenderbuffers = @as(@TypeOf(function_pointers.glGenRenderbuffers), @ptrCast(proc));
    } else {
        log.err("entry point glGenRenderbuffers not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glRenderbufferStorage")) |proc| {
        function_pointers.glRenderbufferStorage = @as(@TypeOf(function_pointers.glRenderbufferStorage), @ptrCast(proc));
    } else {
        log.err("entry point glRenderbufferStorage not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetRenderbufferParameteriv")) |proc| {
        function_pointers.glGetRenderbufferParameteriv = @as(@TypeOf(function_pointers.glGetRenderbufferParameteriv), @ptrCast(proc));
    } else {
        log.err("entry point glGetRenderbufferParameteriv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glIsFramebuffer")) |proc| {
        function_pointers.glIsFramebuffer = @as(@TypeOf(function_pointers.glIsFramebuffer), @ptrCast(proc));
    } else {
        log.err("entry point glIsFramebuffer not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glBindFramebuffer")) |proc| {
        function_pointers.glBindFramebuffer = @as(@TypeOf(function_pointers.glBindFramebuffer), @ptrCast(proc));
    } else {
        log.err("entry point glBindFramebuffer not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glDeleteFramebuffers")) |proc| {
        function_pointers.glDeleteFramebuffers = @as(@TypeOf(function_pointers.glDeleteFramebuffers), @ptrCast(proc));
    } else {
        log.err("entry point glDeleteFramebuffers not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGenFramebuffers")) |proc| {
        function_pointers.glGenFramebuffers = @as(@TypeOf(function_pointers.glGenFramebuffers), @ptrCast(proc));
    } else {
        log.err("entry point glGenFramebuffers not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glCheckFramebufferStatus")) |proc| {
        function_pointers.glCheckFramebufferStatus = @as(@TypeOf(function_pointers.glCheckFramebufferStatus), @ptrCast(proc));
    } else {
        log.err("entry point glCheckFramebufferStatus not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glFramebufferTexture1D")) |proc| {
        function_pointers.glFramebufferTexture1D = @as(@TypeOf(function_pointers.glFramebufferTexture1D), @ptrCast(proc));
    } else {
        log.err("entry point glFramebufferTexture1D not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glFramebufferTexture2D")) |proc| {
        function_pointers.glFramebufferTexture2D = @as(@TypeOf(function_pointers.glFramebufferTexture2D), @ptrCast(proc));
    } else {
        log.err("entry point glFramebufferTexture2D not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glFramebufferTexture3D")) |proc| {
        function_pointers.glFramebufferTexture3D = @as(@TypeOf(function_pointers.glFramebufferTexture3D), @ptrCast(proc));
    } else {
        log.err("entry point glFramebufferTexture3D not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glFramebufferRenderbuffer")) |proc| {
        function_pointers.glFramebufferRenderbuffer = @as(@TypeOf(function_pointers.glFramebufferRenderbuffer), @ptrCast(proc));
    } else {
        log.err("entry point glFramebufferRenderbuffer not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetFramebufferAttachmentParameteriv")) |proc| {
        function_pointers.glGetFramebufferAttachmentParameteriv = @as(@TypeOf(function_pointers.glGetFramebufferAttachmentParameteriv), @ptrCast(proc));
    } else {
        log.err("entry point glGetFramebufferAttachmentParameteriv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGenerateMipmap")) |proc| {
        function_pointers.glGenerateMipmap = @as(@TypeOf(function_pointers.glGenerateMipmap), @ptrCast(proc));
    } else {
        log.err("entry point glGenerateMipmap not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glBlitFramebuffer")) |proc| {
        function_pointers.glBlitFramebuffer = @as(@TypeOf(function_pointers.glBlitFramebuffer), @ptrCast(proc));
    } else {
        log.err("entry point glBlitFramebuffer not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glRenderbufferStorageMultisample")) |proc| {
        function_pointers.glRenderbufferStorageMultisample = @as(@TypeOf(function_pointers.glRenderbufferStorageMultisample), @ptrCast(proc));
    } else {
        log.err("entry point glRenderbufferStorageMultisample not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glFramebufferTextureLayer")) |proc| {
        function_pointers.glFramebufferTextureLayer = @as(@TypeOf(function_pointers.glFramebufferTextureLayer), @ptrCast(proc));
    } else {
        log.err("entry point glFramebufferTextureLayer not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glMapBufferRange")) |proc| {
        function_pointers.glMapBufferRange = @as(@TypeOf(function_pointers.glMapBufferRange), @ptrCast(proc));
    } else {
        log.err("entry point glMapBufferRange not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glFlushMappedBufferRange")) |proc| {
        function_pointers.glFlushMappedBufferRange = @as(@TypeOf(function_pointers.glFlushMappedBufferRange), @ptrCast(proc));
    } else {
        log.err("entry point glFlushMappedBufferRange not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glBindVertexArray")) |proc| {
        function_pointers.glBindVertexArray = @as(@TypeOf(function_pointers.glBindVertexArray), @ptrCast(proc));
    } else {
        log.err("entry point glBindVertexArray not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glDeleteVertexArrays")) |proc| {
        function_pointers.glDeleteVertexArrays = @as(@TypeOf(function_pointers.glDeleteVertexArrays), @ptrCast(proc));
    } else {
        log.err("entry point glDeleteVertexArrays not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGenVertexArrays")) |proc| {
        function_pointers.glGenVertexArrays = @as(@TypeOf(function_pointers.glGenVertexArrays), @ptrCast(proc));
    } else {
        log.err("entry point glGenVertexArrays not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glIsVertexArray")) |proc| {
        function_pointers.glIsVertexArray = @as(@TypeOf(function_pointers.glIsVertexArray), @ptrCast(proc));
    } else {
        log.err("entry point glIsVertexArray not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glDrawArraysInstanced")) |proc| {
        function_pointers.glDrawArraysInstanced = @as(@TypeOf(function_pointers.glDrawArraysInstanced), @ptrCast(proc));
    } else {
        log.err("entry point glDrawArraysInstanced not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glDrawElementsInstanced")) |proc| {
        function_pointers.glDrawElementsInstanced = @as(@TypeOf(function_pointers.glDrawElementsInstanced), @ptrCast(proc));
    } else {
        log.err("entry point glDrawElementsInstanced not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glTexBuffer")) |proc| {
        function_pointers.glTexBuffer = @as(@TypeOf(function_pointers.glTexBuffer), @ptrCast(proc));
    } else {
        log.err("entry point glTexBuffer not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glPrimitiveRestartIndex")) |proc| {
        function_pointers.glPrimitiveRestartIndex = @as(@TypeOf(function_pointers.glPrimitiveRestartIndex), @ptrCast(proc));
    } else {
        log.err("entry point glPrimitiveRestartIndex not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glCopyBufferSubData")) |proc| {
        function_pointers.glCopyBufferSubData = @as(@TypeOf(function_pointers.glCopyBufferSubData), @ptrCast(proc));
    } else {
        log.err("entry point glCopyBufferSubData not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetUniformIndices")) |proc| {
        function_pointers.glGetUniformIndices = @as(@TypeOf(function_pointers.glGetUniformIndices), @ptrCast(proc));
    } else {
        log.err("entry point glGetUniformIndices not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetActiveUniformsiv")) |proc| {
        function_pointers.glGetActiveUniformsiv = @as(@TypeOf(function_pointers.glGetActiveUniformsiv), @ptrCast(proc));
    } else {
        log.err("entry point glGetActiveUniformsiv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetActiveUniformName")) |proc| {
        function_pointers.glGetActiveUniformName = @as(@TypeOf(function_pointers.glGetActiveUniformName), @ptrCast(proc));
    } else {
        log.err("entry point glGetActiveUniformName not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetUniformBlockIndex")) |proc| {
        function_pointers.glGetUniformBlockIndex = @as(@TypeOf(function_pointers.glGetUniformBlockIndex), @ptrCast(proc));
    } else {
        log.err("entry point glGetUniformBlockIndex not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetActiveUniformBlockiv")) |proc| {
        function_pointers.glGetActiveUniformBlockiv = @as(@TypeOf(function_pointers.glGetActiveUniformBlockiv), @ptrCast(proc));
    } else {
        log.err("entry point glGetActiveUniformBlockiv not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glGetActiveUniformBlockName")) |proc| {
        function_pointers.glGetActiveUniformBlockName = @as(@TypeOf(function_pointers.glGetActiveUniformBlockName), @ptrCast(proc));
    } else {
        log.err("entry point glGetActiveUniformBlockName not found!", .{});
        success = false;
    }
    if (get_proc_address(load_ctx, "glUniformBlockBinding")) |proc| {
        function_pointers.glUniformBlockBinding = @as(@TypeOf(function_pointers.glUniformBlockBinding), @ptrCast(proc));
    } else {
        log.err("entry point glUniformBlockBinding not found!", .{});
        success = false;
    }
    if (!success)
        return error.EntryPointNotFound;
}

const function_signatures = struct {
    const glCullFace = fn (_mode: GLenum) callconv(.C) void;
    const glFrontFace = fn (_mode: GLenum) callconv(.C) void;
    const glHint = fn (_target: GLenum, _mode: GLenum) callconv(.C) void;
    const glLineWidth = fn (_width: GLfloat) callconv(.C) void;
    const glPointSize = fn (_size: GLfloat) callconv(.C) void;
    const glPolygonMode = fn (_face: GLenum, _mode: GLenum) callconv(.C) void;
    const glScissor = fn (_x: GLint, _y: GLint, _width: GLsizei, _height: GLsizei) callconv(.C) void;
    const glTexParameterf = fn (_target: GLenum, _pname: GLenum, _param: GLfloat) callconv(.C) void;
    const glTexParameterfv = fn (_target: GLenum, _pname: GLenum, _params: [*c]const GLfloat) callconv(.C) void;
    const glTexParameteri = fn (_target: GLenum, _pname: GLenum, _param: GLint) callconv(.C) void;
    const glTexParameteriv = fn (_target: GLenum, _pname: GLenum, _params: [*c]const GLint) callconv(.C) void;
    const glTexImage1D = fn (_target: GLenum, _level: GLint, _internalformat: GLint, _width: GLsizei, _border: GLint, _format: GLenum, _type: GLenum, _pixels: ?*const anyopaque) callconv(.C) void;
    const glTexImage2D = fn (_target: GLenum, _level: GLint, _internalformat: GLint, _width: GLsizei, _height: GLsizei, _border: GLint, _format: GLenum, _type: GLenum, _pixels: ?*const anyopaque) callconv(.C) void;
    const glDrawBuffer = fn (_buf: GLenum) callconv(.C) void;
    const glClear = fn (_mask: GLbitfield) callconv(.C) void;
    const glClearColor = fn (_red: GLfloat, _green: GLfloat, _blue: GLfloat, _alpha: GLfloat) callconv(.C) void;
    const glClearStencil = fn (_s: GLint) callconv(.C) void;
    const glClearDepth = fn (_depth: GLdouble) callconv(.C) void;
    const glStencilMask = fn (_mask: GLuint) callconv(.C) void;
    const glColorMask = fn (_red: GLboolean, _green: GLboolean, _blue: GLboolean, _alpha: GLboolean) callconv(.C) void;
    const glDepthMask = fn (_flag: GLboolean) callconv(.C) void;
    const glDisable = fn (_cap: GLenum) callconv(.C) void;
    const glEnable = fn (_cap: GLenum) callconv(.C) void;
    const glFinish = fn () callconv(.C) void;
    const glFlush = fn () callconv(.C) void;
    const glBlendFunc = fn (_sfactor: GLenum, _dfactor: GLenum) callconv(.C) void;
    const glLogicOp = fn (_opcode: GLenum) callconv(.C) void;
    const glStencilFunc = fn (_func: GLenum, _ref: GLint, _mask: GLuint) callconv(.C) void;
    const glStencilOp = fn (_fail: GLenum, _zfail: GLenum, _zpass: GLenum) callconv(.C) void;
    const glDepthFunc = fn (_func: GLenum) callconv(.C) void;
    const glPixelStoref = fn (_pname: GLenum, _param: GLfloat) callconv(.C) void;
    const glPixelStorei = fn (_pname: GLenum, _param: GLint) callconv(.C) void;
    const glReadBuffer = fn (_src: GLenum) callconv(.C) void;
    const glReadPixels = fn (_x: GLint, _y: GLint, _width: GLsizei, _height: GLsizei, _format: GLenum, _type: GLenum, _pixels: ?*anyopaque) callconv(.C) void;
    const glGetBooleanv = fn (_pname: GLenum, _data: [*c]GLboolean) callconv(.C) void;
    const glGetDoublev = fn (_pname: GLenum, _data: [*c]GLdouble) callconv(.C) void;
    const glGetError = fn () callconv(.C) GLenum;
    const glGetFloatv = fn (_pname: GLenum, _data: [*c]GLfloat) callconv(.C) void;
    const glGetIntegerv = fn (_pname: GLenum, _data: [*c]GLint) callconv(.C) void;
    const glGetString = fn (_name: GLenum) callconv(.C) ?[*:0]const GLubyte;
    const glGetTexImage = fn (_target: GLenum, _level: GLint, _format: GLenum, _type: GLenum, _pixels: ?*anyopaque) callconv(.C) void;
    const glGetTexParameterfv = fn (_target: GLenum, _pname: GLenum, _params: [*c]GLfloat) callconv(.C) void;
    const glGetTexParameteriv = fn (_target: GLenum, _pname: GLenum, _params: [*c]GLint) callconv(.C) void;
    const glGetTexLevelParameterfv = fn (_target: GLenum, _level: GLint, _pname: GLenum, _params: [*c]GLfloat) callconv(.C) void;
    const glGetTexLevelParameteriv = fn (_target: GLenum, _level: GLint, _pname: GLenum, _params: [*c]GLint) callconv(.C) void;
    const glIsEnabled = fn (_cap: GLenum) callconv(.C) GLboolean;
    const glDepthRange = fn (_n: GLdouble, _f: GLdouble) callconv(.C) void;
    const glViewport = fn (_x: GLint, _y: GLint, _width: GLsizei, _height: GLsizei) callconv(.C) void;
    const glDrawArrays = fn (_mode: GLenum, _first: GLint, _count: GLsizei) callconv(.C) void;
    const glDrawElements = fn (_mode: GLenum, _count: GLsizei, _type: GLenum, _indices: ?*const anyopaque) callconv(.C) void;
    const glPolygonOffset = fn (_factor: GLfloat, _units: GLfloat) callconv(.C) void;
    const glCopyTexImage1D = fn (_target: GLenum, _level: GLint, _internalformat: GLenum, _x: GLint, _y: GLint, _width: GLsizei, _border: GLint) callconv(.C) void;
    const glCopyTexImage2D = fn (_target: GLenum, _level: GLint, _internalformat: GLenum, _x: GLint, _y: GLint, _width: GLsizei, _height: GLsizei, _border: GLint) callconv(.C) void;
    const glCopyTexSubImage1D = fn (_target: GLenum, _level: GLint, _xoffset: GLint, _x: GLint, _y: GLint, _width: GLsizei) callconv(.C) void;
    const glCopyTexSubImage2D = fn (_target: GLenum, _level: GLint, _xoffset: GLint, _yoffset: GLint, _x: GLint, _y: GLint, _width: GLsizei, _height: GLsizei) callconv(.C) void;
    const glTexSubImage1D = fn (_target: GLenum, _level: GLint, _xoffset: GLint, _width: GLsizei, _format: GLenum, _type: GLenum, _pixels: ?*const anyopaque) callconv(.C) void;
    const glTexSubImage2D = fn (_target: GLenum, _level: GLint, _xoffset: GLint, _yoffset: GLint, _width: GLsizei, _height: GLsizei, _format: GLenum, _type: GLenum, _pixels: ?*const anyopaque) callconv(.C) void;
    const glBindTexture = fn (_target: GLenum, _texture: GLuint) callconv(.C) void;
    const glDeleteTextures = fn (_n: GLsizei, _textures: [*c]const GLuint) callconv(.C) void;
    const glGenTextures = fn (_n: GLsizei, _textures: [*c]GLuint) callconv(.C) void;
    const glIsTexture = fn (_texture: GLuint) callconv(.C) GLboolean;
    const glDrawRangeElements = fn (_mode: GLenum, _start: GLuint, _end: GLuint, _count: GLsizei, _type: GLenum, _indices: ?*const anyopaque) callconv(.C) void;
    const glTexImage3D = fn (_target: GLenum, _level: GLint, _internalformat: GLint, _width: GLsizei, _height: GLsizei, _depth: GLsizei, _border: GLint, _format: GLenum, _type: GLenum, _pixels: ?*const anyopaque) callconv(.C) void;
    const glTexSubImage3D = fn (_target: GLenum, _level: GLint, _xoffset: GLint, _yoffset: GLint, _zoffset: GLint, _width: GLsizei, _height: GLsizei, _depth: GLsizei, _format: GLenum, _type: GLenum, _pixels: ?*const anyopaque) callconv(.C) void;
    const glCopyTexSubImage3D = fn (_target: GLenum, _level: GLint, _xoffset: GLint, _yoffset: GLint, _zoffset: GLint, _x: GLint, _y: GLint, _width: GLsizei, _height: GLsizei) callconv(.C) void;
    const glActiveTexture = fn (_texture: GLenum) callconv(.C) void;
    const glSampleCoverage = fn (_value: GLfloat, _invert: GLboolean) callconv(.C) void;
    const glCompressedTexImage3D = fn (_target: GLenum, _level: GLint, _internalformat: GLenum, _width: GLsizei, _height: GLsizei, _depth: GLsizei, _border: GLint, _imageSize: GLsizei, _data: ?*const anyopaque) callconv(.C) void;
    const glCompressedTexImage2D = fn (_target: GLenum, _level: GLint, _internalformat: GLenum, _width: GLsizei, _height: GLsizei, _border: GLint, _imageSize: GLsizei, _data: ?*const anyopaque) callconv(.C) void;
    const glCompressedTexImage1D = fn (_target: GLenum, _level: GLint, _internalformat: GLenum, _width: GLsizei, _border: GLint, _imageSize: GLsizei, _data: ?*const anyopaque) callconv(.C) void;
    const glCompressedTexSubImage3D = fn (_target: GLenum, _level: GLint, _xoffset: GLint, _yoffset: GLint, _zoffset: GLint, _width: GLsizei, _height: GLsizei, _depth: GLsizei, _format: GLenum, _imageSize: GLsizei, _data: ?*const anyopaque) callconv(.C) void;
    const glCompressedTexSubImage2D = fn (_target: GLenum, _level: GLint, _xoffset: GLint, _yoffset: GLint, _width: GLsizei, _height: GLsizei, _format: GLenum, _imageSize: GLsizei, _data: ?*const anyopaque) callconv(.C) void;
    const glCompressedTexSubImage1D = fn (_target: GLenum, _level: GLint, _xoffset: GLint, _width: GLsizei, _format: GLenum, _imageSize: GLsizei, _data: ?*const anyopaque) callconv(.C) void;
    const glGetCompressedTexImage = fn (_target: GLenum, _level: GLint, _img: ?*anyopaque) callconv(.C) void;
    const glVertexAttribP4uiv = fn (_index: GLuint, _type: GLenum, _normalized: GLboolean, _value: [*c]const GLuint) callconv(.C) void;
    const glVertexAttribP4ui = fn (_index: GLuint, _type: GLenum, _normalized: GLboolean, _value: GLuint) callconv(.C) void;
    const glVertexAttribP3uiv = fn (_index: GLuint, _type: GLenum, _normalized: GLboolean, _value: [*c]const GLuint) callconv(.C) void;
    const glVertexAttribP3ui = fn (_index: GLuint, _type: GLenum, _normalized: GLboolean, _value: GLuint) callconv(.C) void;
    const glVertexAttribP2uiv = fn (_index: GLuint, _type: GLenum, _normalized: GLboolean, _value: [*c]const GLuint) callconv(.C) void;
    const glVertexAttribP2ui = fn (_index: GLuint, _type: GLenum, _normalized: GLboolean, _value: GLuint) callconv(.C) void;
    const glVertexAttribP1uiv = fn (_index: GLuint, _type: GLenum, _normalized: GLboolean, _value: [*c]const GLuint) callconv(.C) void;
    const glVertexAttribP1ui = fn (_index: GLuint, _type: GLenum, _normalized: GLboolean, _value: GLuint) callconv(.C) void;
    const glVertexAttribDivisor = fn (_index: GLuint, _divisor: GLuint) callconv(.C) void;
    const glGetQueryObjectui64v = fn (_id: GLuint, _pname: GLenum, _params: [*c]GLuint64) callconv(.C) void;
    const glGetQueryObjecti64v = fn (_id: GLuint, _pname: GLenum, _params: [*c]GLint64) callconv(.C) void;
    const glQueryCounter = fn (_id: GLuint, _target: GLenum) callconv(.C) void;
    const glGetSamplerParameterIuiv = fn (_sampler: GLuint, _pname: GLenum, _params: [*c]GLuint) callconv(.C) void;
    const glGetSamplerParameterfv = fn (_sampler: GLuint, _pname: GLenum, _params: [*c]GLfloat) callconv(.C) void;
    const glGetSamplerParameterIiv = fn (_sampler: GLuint, _pname: GLenum, _params: [*c]GLint) callconv(.C) void;
    const glGetSamplerParameteriv = fn (_sampler: GLuint, _pname: GLenum, _params: [*c]GLint) callconv(.C) void;
    const glSamplerParameterIuiv = fn (_sampler: GLuint, _pname: GLenum, _param: [*c]const GLuint) callconv(.C) void;
    const glSamplerParameterIiv = fn (_sampler: GLuint, _pname: GLenum, _param: [*c]const GLint) callconv(.C) void;
    const glSamplerParameterfv = fn (_sampler: GLuint, _pname: GLenum, _param: [*c]const GLfloat) callconv(.C) void;
    const glSamplerParameterf = fn (_sampler: GLuint, _pname: GLenum, _param: GLfloat) callconv(.C) void;
    const glSamplerParameteriv = fn (_sampler: GLuint, _pname: GLenum, _param: [*c]const GLint) callconv(.C) void;
    const glSamplerParameteri = fn (_sampler: GLuint, _pname: GLenum, _param: GLint) callconv(.C) void;
    const glBindSampler = fn (_unit: GLuint, _sampler: GLuint) callconv(.C) void;
    const glIsSampler = fn (_sampler: GLuint) callconv(.C) GLboolean;
    const glDeleteSamplers = fn (_count: GLsizei, _samplers: [*c]const GLuint) callconv(.C) void;
    const glGenSamplers = fn (_count: GLsizei, _samplers: [*c]GLuint) callconv(.C) void;
    const glGetFragDataIndex = fn (_program: GLuint, _name: [*c]const GLchar) callconv(.C) GLint;
    const glBindFragDataLocationIndexed = fn (_program: GLuint, _colorNumber: GLuint, _index: GLuint, _name: [*c]const GLchar) callconv(.C) void;
    const glSampleMaski = fn (_maskNumber: GLuint, _mask: GLbitfield) callconv(.C) void;
    const glGetMultisamplefv = fn (_pname: GLenum, _index: GLuint, _val: [*c]GLfloat) callconv(.C) void;
    const glTexImage3DMultisample = fn (_target: GLenum, _samples: GLsizei, _internalformat: GLenum, _width: GLsizei, _height: GLsizei, _depth: GLsizei, _fixedsamplelocations: GLboolean) callconv(.C) void;
    const glTexImage2DMultisample = fn (_target: GLenum, _samples: GLsizei, _internalformat: GLenum, _width: GLsizei, _height: GLsizei, _fixedsamplelocations: GLboolean) callconv(.C) void;
    const glFramebufferTexture = fn (_target: GLenum, _attachment: GLenum, _texture: GLuint, _level: GLint) callconv(.C) void;
    const glGetBufferParameteri64v = fn (_target: GLenum, _pname: GLenum, _params: [*c]GLint64) callconv(.C) void;
    const glBlendFuncSeparate = fn (_sfactorRGB: GLenum, _dfactorRGB: GLenum, _sfactorAlpha: GLenum, _dfactorAlpha: GLenum) callconv(.C) void;
    const glMultiDrawArrays = fn (_mode: GLenum, _first: [*c]const GLint, _count: [*c]const GLsizei, _drawcount: GLsizei) callconv(.C) void;
    const glMultiDrawElements = fn (_mode: GLenum, _count: [*c]const GLsizei, _type: GLenum, _indices: [*c]const ?*const anyopaque, _drawcount: GLsizei) callconv(.C) void;
    const glPointParameterf = fn (_pname: GLenum, _param: GLfloat) callconv(.C) void;
    const glPointParameterfv = fn (_pname: GLenum, _params: [*c]const GLfloat) callconv(.C) void;
    const glPointParameteri = fn (_pname: GLenum, _param: GLint) callconv(.C) void;
    const glPointParameteriv = fn (_pname: GLenum, _params: [*c]const GLint) callconv(.C) void;
    const glGetInteger64i_v = fn (_target: GLenum, _index: GLuint, _data: [*c]GLint64) callconv(.C) void;
    const glGetSynciv = fn (_sync: GLsync, _pname: GLenum, _count: GLsizei, _length: [*c]GLsizei, _values: [*c]GLint) callconv(.C) void;
    const glGetInteger64v = fn (_pname: GLenum, _data: [*c]GLint64) callconv(.C) void;
    const glWaitSync = fn (_sync: GLsync, _flags: GLbitfield, _timeout: GLuint64) callconv(.C) void;
    const glClientWaitSync = fn (_sync: GLsync, _flags: GLbitfield, _timeout: GLuint64) callconv(.C) GLenum;
    const glDeleteSync = fn (_sync: GLsync) callconv(.C) void;
    const glIsSync = fn (_sync: GLsync) callconv(.C) GLboolean;
    const glFenceSync = fn (_condition: GLenum, _flags: GLbitfield) callconv(.C) GLsync;
    const glBlendColor = fn (_red: GLfloat, _green: GLfloat, _blue: GLfloat, _alpha: GLfloat) callconv(.C) void;
    const glBlendEquation = fn (_mode: GLenum) callconv(.C) void;
    const glProvokingVertex = fn (_mode: GLenum) callconv(.C) void;
    const glMultiDrawElementsBaseVertex = fn (_mode: GLenum, _count: [*c]const GLsizei, _type: GLenum, _indices: [*c]const ?*const anyopaque, _drawcount: GLsizei, _basevertex: [*c]const GLint) callconv(.C) void;
    const glDrawElementsInstancedBaseVertex = fn (_mode: GLenum, _count: GLsizei, _type: GLenum, _indices: ?*const anyopaque, _instancecount: GLsizei, _basevertex: GLint) callconv(.C) void;
    const glDrawRangeElementsBaseVertex = fn (_mode: GLenum, _start: GLuint, _end: GLuint, _count: GLsizei, _type: GLenum, _indices: ?*const anyopaque, _basevertex: GLint) callconv(.C) void;
    const glDrawElementsBaseVertex = fn (_mode: GLenum, _count: GLsizei, _type: GLenum, _indices: ?*const anyopaque, _basevertex: GLint) callconv(.C) void;
    const glGenQueries = fn (_n: GLsizei, _ids: [*c]GLuint) callconv(.C) void;
    const glDeleteQueries = fn (_n: GLsizei, _ids: [*c]const GLuint) callconv(.C) void;
    const glIsQuery = fn (_id: GLuint) callconv(.C) GLboolean;
    const glBeginQuery = fn (_target: GLenum, _id: GLuint) callconv(.C) void;
    const glEndQuery = fn (_target: GLenum) callconv(.C) void;
    const glGetQueryiv = fn (_target: GLenum, _pname: GLenum, _params: [*c]GLint) callconv(.C) void;
    const glGetQueryObjectiv = fn (_id: GLuint, _pname: GLenum, _params: [*c]GLint) callconv(.C) void;
    const glGetQueryObjectuiv = fn (_id: GLuint, _pname: GLenum, _params: [*c]GLuint) callconv(.C) void;
    const glBindBuffer = fn (_target: GLenum, _buffer: GLuint) callconv(.C) void;
    const glDeleteBuffers = fn (_n: GLsizei, _buffers: [*c]const GLuint) callconv(.C) void;
    const glGenBuffers = fn (_n: GLsizei, _buffers: [*c]GLuint) callconv(.C) void;
    const glIsBuffer = fn (_buffer: GLuint) callconv(.C) GLboolean;
    const glBufferData = fn (_target: GLenum, _size: GLsizeiptr, _data: ?*const anyopaque, _usage: GLenum) callconv(.C) void;
    const glBufferSubData = fn (_target: GLenum, _offset: GLintptr, _size: GLsizeiptr, _data: ?*const anyopaque) callconv(.C) void;
    const glGetBufferSubData = fn (_target: GLenum, _offset: GLintptr, _size: GLsizeiptr, _data: ?*anyopaque) callconv(.C) void;
    const glMapBuffer = fn (_target: GLenum, _access: GLenum) callconv(.C) ?*anyopaque;
    const glUnmapBuffer = fn (_target: GLenum) callconv(.C) GLboolean;
    const glGetBufferParameteriv = fn (_target: GLenum, _pname: GLenum, _params: [*c]GLint) callconv(.C) void;
    const glGetBufferPointerv = fn (_target: GLenum, _pname: GLenum, _params: ?*?*anyopaque) callconv(.C) void;
    const glBlendEquationSeparate = fn (_modeRGB: GLenum, _modeAlpha: GLenum) callconv(.C) void;
    const glDrawBuffers = fn (_n: GLsizei, _bufs: [*c]const GLenum) callconv(.C) void;
    const glStencilOpSeparate = fn (_face: GLenum, _sfail: GLenum, _dpfail: GLenum, _dppass: GLenum) callconv(.C) void;
    const glStencilFuncSeparate = fn (_face: GLenum, _func: GLenum, _ref: GLint, _mask: GLuint) callconv(.C) void;
    const glStencilMaskSeparate = fn (_face: GLenum, _mask: GLuint) callconv(.C) void;
    const glAttachShader = fn (_program: GLuint, _shader: GLuint) callconv(.C) void;
    const glBindAttribLocation = fn (_program: GLuint, _index: GLuint, _name: [*c]const GLchar) callconv(.C) void;
    const glCompileShader = fn (_shader: GLuint) callconv(.C) void;
    const glCreateProgram = fn () callconv(.C) GLuint;
    const glCreateShader = fn (_type: GLenum) callconv(.C) GLuint;
    const glDeleteProgram = fn (_program: GLuint) callconv(.C) void;
    const glDeleteShader = fn (_shader: GLuint) callconv(.C) void;
    const glDetachShader = fn (_program: GLuint, _shader: GLuint) callconv(.C) void;
    const glDisableVertexAttribArray = fn (_index: GLuint) callconv(.C) void;
    const glEnableVertexAttribArray = fn (_index: GLuint) callconv(.C) void;
    const glGetActiveAttrib = fn (_program: GLuint, _index: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _size: [*c]GLint, _type: [*c]GLenum, _name: [*c]GLchar) callconv(.C) void;
    const glGetActiveUniform = fn (_program: GLuint, _index: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _size: [*c]GLint, _type: [*c]GLenum, _name: [*c]GLchar) callconv(.C) void;
    const glGetAttachedShaders = fn (_program: GLuint, _maxCount: GLsizei, _count: [*c]GLsizei, _shaders: [*c]GLuint) callconv(.C) void;
    const glGetAttribLocation = fn (_program: GLuint, _name: [*c]const GLchar) callconv(.C) GLint;
    const glGetProgramiv = fn (_program: GLuint, _pname: GLenum, _params: [*c]GLint) callconv(.C) void;
    const glGetProgramInfoLog = fn (_program: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _infoLog: [*c]GLchar) callconv(.C) void;
    const glGetShaderiv = fn (_shader: GLuint, _pname: GLenum, _params: [*c]GLint) callconv(.C) void;
    const glGetShaderInfoLog = fn (_shader: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _infoLog: [*c]GLchar) callconv(.C) void;
    const glGetShaderSource = fn (_shader: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _source: [*c]GLchar) callconv(.C) void;
    const glGetUniformLocation = fn (_program: GLuint, _name: [*c]const GLchar) callconv(.C) GLint;
    const glGetUniformfv = fn (_program: GLuint, _location: GLint, _params: [*c]GLfloat) callconv(.C) void;
    const glGetUniformiv = fn (_program: GLuint, _location: GLint, _params: [*c]GLint) callconv(.C) void;
    const glGetVertexAttribdv = fn (_index: GLuint, _pname: GLenum, _params: [*c]GLdouble) callconv(.C) void;
    const glGetVertexAttribfv = fn (_index: GLuint, _pname: GLenum, _params: [*c]GLfloat) callconv(.C) void;
    const glGetVertexAttribiv = fn (_index: GLuint, _pname: GLenum, _params: [*c]GLint) callconv(.C) void;
    const glGetVertexAttribPointerv = fn (_index: GLuint, _pname: GLenum, _pointer: ?*?*anyopaque) callconv(.C) void;
    const glIsProgram = fn (_program: GLuint) callconv(.C) GLboolean;
    const glIsShader = fn (_shader: GLuint) callconv(.C) GLboolean;
    const glLinkProgram = fn (_program: GLuint) callconv(.C) void;
    const glShaderSource = fn (_shader: GLuint, _count: GLsizei, _string: [*c]const [*c]const GLchar, _length: [*c]const GLint) callconv(.C) void;
    const glUseProgram = fn (_program: GLuint) callconv(.C) void;
    const glUniform1f = fn (_location: GLint, _v0: GLfloat) callconv(.C) void;
    const glUniform2f = fn (_location: GLint, _v0: GLfloat, _v1: GLfloat) callconv(.C) void;
    const glUniform3f = fn (_location: GLint, _v0: GLfloat, _v1: GLfloat, _v2: GLfloat) callconv(.C) void;
    const glUniform4f = fn (_location: GLint, _v0: GLfloat, _v1: GLfloat, _v2: GLfloat, _v3: GLfloat) callconv(.C) void;
    const glUniform1i = fn (_location: GLint, _v0: GLint) callconv(.C) void;
    const glUniform2i = fn (_location: GLint, _v0: GLint, _v1: GLint) callconv(.C) void;
    const glUniform3i = fn (_location: GLint, _v0: GLint, _v1: GLint, _v2: GLint) callconv(.C) void;
    const glUniform4i = fn (_location: GLint, _v0: GLint, _v1: GLint, _v2: GLint, _v3: GLint) callconv(.C) void;
    const glUniform1fv = fn (_location: GLint, _count: GLsizei, _value: [*c]const GLfloat) callconv(.C) void;
    const glUniform2fv = fn (_location: GLint, _count: GLsizei, _value: [*c]const GLfloat) callconv(.C) void;
    const glUniform3fv = fn (_location: GLint, _count: GLsizei, _value: [*c]const GLfloat) callconv(.C) void;
    const glUniform4fv = fn (_location: GLint, _count: GLsizei, _value: [*c]const GLfloat) callconv(.C) void;
    const glUniform1iv = fn (_location: GLint, _count: GLsizei, _value: [*c]const GLint) callconv(.C) void;
    const glUniform2iv = fn (_location: GLint, _count: GLsizei, _value: [*c]const GLint) callconv(.C) void;
    const glUniform3iv = fn (_location: GLint, _count: GLsizei, _value: [*c]const GLint) callconv(.C) void;
    const glUniform4iv = fn (_location: GLint, _count: GLsizei, _value: [*c]const GLint) callconv(.C) void;
    const glUniformMatrix2fv = fn (_location: GLint, _count: GLsizei, _transpose: GLboolean, _value: [*c]const GLfloat) callconv(.C) void;
    const glUniformMatrix3fv = fn (_location: GLint, _count: GLsizei, _transpose: GLboolean, _value: [*c]const GLfloat) callconv(.C) void;
    const glUniformMatrix4fv = fn (_location: GLint, _count: GLsizei, _transpose: GLboolean, _value: [*c]const GLfloat) callconv(.C) void;
    const glValidateProgram = fn (_program: GLuint) callconv(.C) void;
    const glVertexAttrib1d = fn (_index: GLuint, _x: GLdouble) callconv(.C) void;
    const glVertexAttrib1dv = fn (_index: GLuint, _v: [*c]const GLdouble) callconv(.C) void;
    const glVertexAttrib1f = fn (_index: GLuint, _x: GLfloat) callconv(.C) void;
    const glVertexAttrib1fv = fn (_index: GLuint, _v: [*c]const GLfloat) callconv(.C) void;
    const glVertexAttrib1s = fn (_index: GLuint, _x: GLshort) callconv(.C) void;
    const glVertexAttrib1sv = fn (_index: GLuint, _v: [*c]const GLshort) callconv(.C) void;
    const glVertexAttrib2d = fn (_index: GLuint, _x: GLdouble, _y: GLdouble) callconv(.C) void;
    const glVertexAttrib2dv = fn (_index: GLuint, _v: [*c]const GLdouble) callconv(.C) void;
    const glVertexAttrib2f = fn (_index: GLuint, _x: GLfloat, _y: GLfloat) callconv(.C) void;
    const glVertexAttrib2fv = fn (_index: GLuint, _v: [*c]const GLfloat) callconv(.C) void;
    const glVertexAttrib2s = fn (_index: GLuint, _x: GLshort, _y: GLshort) callconv(.C) void;
    const glVertexAttrib2sv = fn (_index: GLuint, _v: [*c]const GLshort) callconv(.C) void;
    const glVertexAttrib3d = fn (_index: GLuint, _x: GLdouble, _y: GLdouble, _z: GLdouble) callconv(.C) void;
    const glVertexAttrib3dv = fn (_index: GLuint, _v: [*c]const GLdouble) callconv(.C) void;
    const glVertexAttrib3f = fn (_index: GLuint, _x: GLfloat, _y: GLfloat, _z: GLfloat) callconv(.C) void;
    const glVertexAttrib3fv = fn (_index: GLuint, _v: [*c]const GLfloat) callconv(.C) void;
    const glVertexAttrib3s = fn (_index: GLuint, _x: GLshort, _y: GLshort, _z: GLshort) callconv(.C) void;
    const glVertexAttrib3sv = fn (_index: GLuint, _v: [*c]const GLshort) callconv(.C) void;
    const glVertexAttrib4Nbv = fn (_index: GLuint, _v: [*c]const GLbyte) callconv(.C) void;
    const glVertexAttrib4Niv = fn (_index: GLuint, _v: [*c]const GLint) callconv(.C) void;
    const glVertexAttrib4Nsv = fn (_index: GLuint, _v: [*c]const GLshort) callconv(.C) void;
    const glVertexAttrib4Nub = fn (_index: GLuint, _x: GLubyte, _y: GLubyte, _z: GLubyte, _w: GLubyte) callconv(.C) void;
    const glVertexAttrib4Nubv = fn (_index: GLuint, _v: ?[*:0]const GLubyte) callconv(.C) void;
    const glVertexAttrib4Nuiv = fn (_index: GLuint, _v: [*c]const GLuint) callconv(.C) void;
    const glVertexAttrib4Nusv = fn (_index: GLuint, _v: [*c]const GLushort) callconv(.C) void;
    const glVertexAttrib4bv = fn (_index: GLuint, _v: [*c]const GLbyte) callconv(.C) void;
    const glVertexAttrib4d = fn (_index: GLuint, _x: GLdouble, _y: GLdouble, _z: GLdouble, _w: GLdouble) callconv(.C) void;
    const glVertexAttrib4dv = fn (_index: GLuint, _v: [*c]const GLdouble) callconv(.C) void;
    const glVertexAttrib4f = fn (_index: GLuint, _x: GLfloat, _y: GLfloat, _z: GLfloat, _w: GLfloat) callconv(.C) void;
    const glVertexAttrib4fv = fn (_index: GLuint, _v: [*c]const GLfloat) callconv(.C) void;
    const glVertexAttrib4iv = fn (_index: GLuint, _v: [*c]const GLint) callconv(.C) void;
    const glVertexAttrib4s = fn (_index: GLuint, _x: GLshort, _y: GLshort, _z: GLshort, _w: GLshort) callconv(.C) void;
    const glVertexAttrib4sv = fn (_index: GLuint, _v: [*c]const GLshort) callconv(.C) void;
    const glVertexAttrib4ubv = fn (_index: GLuint, _v: ?[*:0]const GLubyte) callconv(.C) void;
    const glVertexAttrib4uiv = fn (_index: GLuint, _v: [*c]const GLuint) callconv(.C) void;
    const glVertexAttrib4usv = fn (_index: GLuint, _v: [*c]const GLushort) callconv(.C) void;
    const glVertexAttribPointer = fn (_index: GLuint, _size: GLint, _type: GLenum, _normalized: GLboolean, _stride: GLsizei, _pointer: ?*const anyopaque) callconv(.C) void;
    const glUniformMatrix2x3fv = fn (_location: GLint, _count: GLsizei, _transpose: GLboolean, _value: [*c]const GLfloat) callconv(.C) void;
    const glUniformMatrix3x2fv = fn (_location: GLint, _count: GLsizei, _transpose: GLboolean, _value: [*c]const GLfloat) callconv(.C) void;
    const glUniformMatrix2x4fv = fn (_location: GLint, _count: GLsizei, _transpose: GLboolean, _value: [*c]const GLfloat) callconv(.C) void;
    const glUniformMatrix4x2fv = fn (_location: GLint, _count: GLsizei, _transpose: GLboolean, _value: [*c]const GLfloat) callconv(.C) void;
    const glUniformMatrix3x4fv = fn (_location: GLint, _count: GLsizei, _transpose: GLboolean, _value: [*c]const GLfloat) callconv(.C) void;
    const glUniformMatrix4x3fv = fn (_location: GLint, _count: GLsizei, _transpose: GLboolean, _value: [*c]const GLfloat) callconv(.C) void;
    const glColorMaski = fn (_index: GLuint, _r: GLboolean, _g: GLboolean, _b: GLboolean, _a: GLboolean) callconv(.C) void;
    const glGetBooleani_v = fn (_target: GLenum, _index: GLuint, _data: [*c]GLboolean) callconv(.C) void;
    const glGetIntegeri_v = fn (_target: GLenum, _index: GLuint, _data: [*c]GLint) callconv(.C) void;
    const glEnablei = fn (_target: GLenum, _index: GLuint) callconv(.C) void;
    const glDisablei = fn (_target: GLenum, _index: GLuint) callconv(.C) void;
    const glIsEnabledi = fn (_target: GLenum, _index: GLuint) callconv(.C) GLboolean;
    const glBeginTransformFeedback = fn (_primitiveMode: GLenum) callconv(.C) void;
    const glEndTransformFeedback = fn () callconv(.C) void;
    const glBindBufferRange = fn (_target: GLenum, _index: GLuint, _buffer: GLuint, _offset: GLintptr, _size: GLsizeiptr) callconv(.C) void;
    const glBindBufferBase = fn (_target: GLenum, _index: GLuint, _buffer: GLuint) callconv(.C) void;
    const glTransformFeedbackVaryings = fn (_program: GLuint, _count: GLsizei, _varyings: [*c]const [*c]const GLchar, _bufferMode: GLenum) callconv(.C) void;
    const glGetTransformFeedbackVarying = fn (_program: GLuint, _index: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _size: [*c]GLsizei, _type: [*c]GLenum, _name: [*c]GLchar) callconv(.C) void;
    const glClampColor = fn (_target: GLenum, _clamp: GLenum) callconv(.C) void;
    const glBeginConditionalRender = fn (_id: GLuint, _mode: GLenum) callconv(.C) void;
    const glEndConditionalRender = fn () callconv(.C) void;
    const glVertexAttribIPointer = fn (_index: GLuint, _size: GLint, _type: GLenum, _stride: GLsizei, _pointer: ?*const anyopaque) callconv(.C) void;
    const glGetVertexAttribIiv = fn (_index: GLuint, _pname: GLenum, _params: [*c]GLint) callconv(.C) void;
    const glGetVertexAttribIuiv = fn (_index: GLuint, _pname: GLenum, _params: [*c]GLuint) callconv(.C) void;
    const glVertexAttribI1i = fn (_index: GLuint, _x: GLint) callconv(.C) void;
    const glVertexAttribI2i = fn (_index: GLuint, _x: GLint, _y: GLint) callconv(.C) void;
    const glVertexAttribI3i = fn (_index: GLuint, _x: GLint, _y: GLint, _z: GLint) callconv(.C) void;
    const glVertexAttribI4i = fn (_index: GLuint, _x: GLint, _y: GLint, _z: GLint, _w: GLint) callconv(.C) void;
    const glVertexAttribI1ui = fn (_index: GLuint, _x: GLuint) callconv(.C) void;
    const glVertexAttribI2ui = fn (_index: GLuint, _x: GLuint, _y: GLuint) callconv(.C) void;
    const glVertexAttribI3ui = fn (_index: GLuint, _x: GLuint, _y: GLuint, _z: GLuint) callconv(.C) void;
    const glVertexAttribI4ui = fn (_index: GLuint, _x: GLuint, _y: GLuint, _z: GLuint, _w: GLuint) callconv(.C) void;
    const glVertexAttribI1iv = fn (_index: GLuint, _v: [*c]const GLint) callconv(.C) void;
    const glVertexAttribI2iv = fn (_index: GLuint, _v: [*c]const GLint) callconv(.C) void;
    const glVertexAttribI3iv = fn (_index: GLuint, _v: [*c]const GLint) callconv(.C) void;
    const glVertexAttribI4iv = fn (_index: GLuint, _v: [*c]const GLint) callconv(.C) void;
    const glVertexAttribI1uiv = fn (_index: GLuint, _v: [*c]const GLuint) callconv(.C) void;
    const glVertexAttribI2uiv = fn (_index: GLuint, _v: [*c]const GLuint) callconv(.C) void;
    const glVertexAttribI3uiv = fn (_index: GLuint, _v: [*c]const GLuint) callconv(.C) void;
    const glVertexAttribI4uiv = fn (_index: GLuint, _v: [*c]const GLuint) callconv(.C) void;
    const glVertexAttribI4bv = fn (_index: GLuint, _v: [*c]const GLbyte) callconv(.C) void;
    const glVertexAttribI4sv = fn (_index: GLuint, _v: [*c]const GLshort) callconv(.C) void;
    const glVertexAttribI4ubv = fn (_index: GLuint, _v: ?[*:0]const GLubyte) callconv(.C) void;
    const glVertexAttribI4usv = fn (_index: GLuint, _v: [*c]const GLushort) callconv(.C) void;
    const glGetUniformuiv = fn (_program: GLuint, _location: GLint, _params: [*c]GLuint) callconv(.C) void;
    const glBindFragDataLocation = fn (_program: GLuint, _color: GLuint, _name: [*c]const GLchar) callconv(.C) void;
    const glGetFragDataLocation = fn (_program: GLuint, _name: [*c]const GLchar) callconv(.C) GLint;
    const glUniform1ui = fn (_location: GLint, _v0: GLuint) callconv(.C) void;
    const glUniform2ui = fn (_location: GLint, _v0: GLuint, _v1: GLuint) callconv(.C) void;
    const glUniform3ui = fn (_location: GLint, _v0: GLuint, _v1: GLuint, _v2: GLuint) callconv(.C) void;
    const glUniform4ui = fn (_location: GLint, _v0: GLuint, _v1: GLuint, _v2: GLuint, _v3: GLuint) callconv(.C) void;
    const glUniform1uiv = fn (_location: GLint, _count: GLsizei, _value: [*c]const GLuint) callconv(.C) void;
    const glUniform2uiv = fn (_location: GLint, _count: GLsizei, _value: [*c]const GLuint) callconv(.C) void;
    const glUniform3uiv = fn (_location: GLint, _count: GLsizei, _value: [*c]const GLuint) callconv(.C) void;
    const glUniform4uiv = fn (_location: GLint, _count: GLsizei, _value: [*c]const GLuint) callconv(.C) void;
    const glTexParameterIiv = fn (_target: GLenum, _pname: GLenum, _params: [*c]const GLint) callconv(.C) void;
    const glTexParameterIuiv = fn (_target: GLenum, _pname: GLenum, _params: [*c]const GLuint) callconv(.C) void;
    const glGetTexParameterIiv = fn (_target: GLenum, _pname: GLenum, _params: [*c]GLint) callconv(.C) void;
    const glGetTexParameterIuiv = fn (_target: GLenum, _pname: GLenum, _params: [*c]GLuint) callconv(.C) void;
    const glClearBufferiv = fn (_buffer: GLenum, _drawbuffer: GLint, _value: [*c]const GLint) callconv(.C) void;
    const glClearBufferuiv = fn (_buffer: GLenum, _drawbuffer: GLint, _value: [*c]const GLuint) callconv(.C) void;
    const glClearBufferfv = fn (_buffer: GLenum, _drawbuffer: GLint, _value: [*c]const GLfloat) callconv(.C) void;
    const glClearBufferfi = fn (_buffer: GLenum, _drawbuffer: GLint, _depth: GLfloat, _stencil: GLint) callconv(.C) void;
    const glGetStringi = fn (_name: GLenum, _index: GLuint) callconv(.C) ?[*:0]const GLubyte;
    const glIsRenderbuffer = fn (_renderbuffer: GLuint) callconv(.C) GLboolean;
    const glBindRenderbuffer = fn (_target: GLenum, _renderbuffer: GLuint) callconv(.C) void;
    const glDeleteRenderbuffers = fn (_n: GLsizei, _renderbuffers: [*c]const GLuint) callconv(.C) void;
    const glGenRenderbuffers = fn (_n: GLsizei, _renderbuffers: [*c]GLuint) callconv(.C) void;
    const glRenderbufferStorage = fn (_target: GLenum, _internalformat: GLenum, _width: GLsizei, _height: GLsizei) callconv(.C) void;
    const glGetRenderbufferParameteriv = fn (_target: GLenum, _pname: GLenum, _params: [*c]GLint) callconv(.C) void;
    const glIsFramebuffer = fn (_framebuffer: GLuint) callconv(.C) GLboolean;
    const glBindFramebuffer = fn (_target: GLenum, _framebuffer: GLuint) callconv(.C) void;
    const glDeleteFramebuffers = fn (_n: GLsizei, _framebuffers: [*c]const GLuint) callconv(.C) void;
    const glGenFramebuffers = fn (_n: GLsizei, _framebuffers: [*c]GLuint) callconv(.C) void;
    const glCheckFramebufferStatus = fn (_target: GLenum) callconv(.C) GLenum;
    const glFramebufferTexture1D = fn (_target: GLenum, _attachment: GLenum, _textarget: GLenum, _texture: GLuint, _level: GLint) callconv(.C) void;
    const glFramebufferTexture2D = fn (_target: GLenum, _attachment: GLenum, _textarget: GLenum, _texture: GLuint, _level: GLint) callconv(.C) void;
    const glFramebufferTexture3D = fn (_target: GLenum, _attachment: GLenum, _textarget: GLenum, _texture: GLuint, _level: GLint, _zoffset: GLint) callconv(.C) void;
    const glFramebufferRenderbuffer = fn (_target: GLenum, _attachment: GLenum, _renderbuffertarget: GLenum, _renderbuffer: GLuint) callconv(.C) void;
    const glGetFramebufferAttachmentParameteriv = fn (_target: GLenum, _attachment: GLenum, _pname: GLenum, _params: [*c]GLint) callconv(.C) void;
    const glGenerateMipmap = fn (_target: GLenum) callconv(.C) void;
    const glBlitFramebuffer = fn (_srcX0: GLint, _srcY0: GLint, _srcX1: GLint, _srcY1: GLint, _dstX0: GLint, _dstY0: GLint, _dstX1: GLint, _dstY1: GLint, _mask: GLbitfield, _filter: GLenum) callconv(.C) void;
    const glRenderbufferStorageMultisample = fn (_target: GLenum, _samples: GLsizei, _internalformat: GLenum, _width: GLsizei, _height: GLsizei) callconv(.C) void;
    const glFramebufferTextureLayer = fn (_target: GLenum, _attachment: GLenum, _texture: GLuint, _level: GLint, _layer: GLint) callconv(.C) void;
    const glMapBufferRange = fn (_target: GLenum, _offset: GLintptr, _length: GLsizeiptr, _access: GLbitfield) callconv(.C) ?*anyopaque;
    const glFlushMappedBufferRange = fn (_target: GLenum, _offset: GLintptr, _length: GLsizeiptr) callconv(.C) void;
    const glBindVertexArray = fn (_array: GLuint) callconv(.C) void;
    const glDeleteVertexArrays = fn (_n: GLsizei, _arrays: [*c]const GLuint) callconv(.C) void;
    const glGenVertexArrays = fn (_n: GLsizei, _arrays: [*c]GLuint) callconv(.C) void;
    const glIsVertexArray = fn (_array: GLuint) callconv(.C) GLboolean;
    const glDrawArraysInstanced = fn (_mode: GLenum, _first: GLint, _count: GLsizei, _instancecount: GLsizei) callconv(.C) void;
    const glDrawElementsInstanced = fn (_mode: GLenum, _count: GLsizei, _type: GLenum, _indices: ?*const anyopaque, _instancecount: GLsizei) callconv(.C) void;
    const glTexBuffer = fn (_target: GLenum, _internalformat: GLenum, _buffer: GLuint) callconv(.C) void;
    const glPrimitiveRestartIndex = fn (_index: GLuint) callconv(.C) void;
    const glCopyBufferSubData = fn (_readTarget: GLenum, _writeTarget: GLenum, _readOffset: GLintptr, _writeOffset: GLintptr, _size: GLsizeiptr) callconv(.C) void;
    const glGetUniformIndices = fn (_program: GLuint, _uniformCount: GLsizei, _uniformNames: [*c]const [*c]const GLchar, _uniformIndices: [*c]GLuint) callconv(.C) void;
    const glGetActiveUniformsiv = fn (_program: GLuint, _uniformCount: GLsizei, _uniformIndices: [*c]const GLuint, _pname: GLenum, _params: [*c]GLint) callconv(.C) void;
    const glGetActiveUniformName = fn (_program: GLuint, _uniformIndex: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _uniformName: [*c]GLchar) callconv(.C) void;
    const glGetUniformBlockIndex = fn (_program: GLuint, _uniformBlockName: [*c]const GLchar) callconv(.C) GLuint;
    const glGetActiveUniformBlockiv = fn (_program: GLuint, _uniformBlockIndex: GLuint, _pname: GLenum, _params: [*c]GLint) callconv(.C) void;
    const glGetActiveUniformBlockName = fn (_program: GLuint, _uniformBlockIndex: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _uniformBlockName: [*c]GLchar) callconv(.C) void;
    const glUniformBlockBinding = fn (_program: GLuint, _uniformBlockIndex: GLuint, _uniformBlockBinding: GLuint) callconv(.C) void;
};

const function_pointers = struct {
    var glCullFace: FnPtr(function_signatures.glCullFace) = undefined;
    var glFrontFace: FnPtr(function_signatures.glFrontFace) = undefined;
    var glHint: FnPtr(function_signatures.glHint) = undefined;
    var glLineWidth: FnPtr(function_signatures.glLineWidth) = undefined;
    var glPointSize: FnPtr(function_signatures.glPointSize) = undefined;
    var glPolygonMode: FnPtr(function_signatures.glPolygonMode) = undefined;
    var glScissor: FnPtr(function_signatures.glScissor) = undefined;
    var glTexParameterf: FnPtr(function_signatures.glTexParameterf) = undefined;
    var glTexParameterfv: FnPtr(function_signatures.glTexParameterfv) = undefined;
    var glTexParameteri: FnPtr(function_signatures.glTexParameteri) = undefined;
    var glTexParameteriv: FnPtr(function_signatures.glTexParameteriv) = undefined;
    var glTexImage1D: FnPtr(function_signatures.glTexImage1D) = undefined;
    var glTexImage2D: FnPtr(function_signatures.glTexImage2D) = undefined;
    var glDrawBuffer: FnPtr(function_signatures.glDrawBuffer) = undefined;
    var glClear: FnPtr(function_signatures.glClear) = undefined;
    var glClearColor: FnPtr(function_signatures.glClearColor) = undefined;
    var glClearStencil: FnPtr(function_signatures.glClearStencil) = undefined;
    var glClearDepth: FnPtr(function_signatures.glClearDepth) = undefined;
    var glStencilMask: FnPtr(function_signatures.glStencilMask) = undefined;
    var glColorMask: FnPtr(function_signatures.glColorMask) = undefined;
    var glDepthMask: FnPtr(function_signatures.glDepthMask) = undefined;
    var glDisable: FnPtr(function_signatures.glDisable) = undefined;
    var glEnable: FnPtr(function_signatures.glEnable) = undefined;
    var glFinish: FnPtr(function_signatures.glFinish) = undefined;
    var glFlush: FnPtr(function_signatures.glFlush) = undefined;
    var glBlendFunc: FnPtr(function_signatures.glBlendFunc) = undefined;
    var glLogicOp: FnPtr(function_signatures.glLogicOp) = undefined;
    var glStencilFunc: FnPtr(function_signatures.glStencilFunc) = undefined;
    var glStencilOp: FnPtr(function_signatures.glStencilOp) = undefined;
    var glDepthFunc: FnPtr(function_signatures.glDepthFunc) = undefined;
    var glPixelStoref: FnPtr(function_signatures.glPixelStoref) = undefined;
    var glPixelStorei: FnPtr(function_signatures.glPixelStorei) = undefined;
    var glReadBuffer: FnPtr(function_signatures.glReadBuffer) = undefined;
    var glReadPixels: FnPtr(function_signatures.glReadPixels) = undefined;
    var glGetBooleanv: FnPtr(function_signatures.glGetBooleanv) = undefined;
    var glGetDoublev: FnPtr(function_signatures.glGetDoublev) = undefined;
    var glGetError: FnPtr(function_signatures.glGetError) = undefined;
    var glGetFloatv: FnPtr(function_signatures.glGetFloatv) = undefined;
    var glGetIntegerv: FnPtr(function_signatures.glGetIntegerv) = undefined;
    var glGetString: FnPtr(function_signatures.glGetString) = undefined;
    var glGetTexImage: FnPtr(function_signatures.glGetTexImage) = undefined;
    var glGetTexParameterfv: FnPtr(function_signatures.glGetTexParameterfv) = undefined;
    var glGetTexParameteriv: FnPtr(function_signatures.glGetTexParameteriv) = undefined;
    var glGetTexLevelParameterfv: FnPtr(function_signatures.glGetTexLevelParameterfv) = undefined;
    var glGetTexLevelParameteriv: FnPtr(function_signatures.glGetTexLevelParameteriv) = undefined;
    var glIsEnabled: FnPtr(function_signatures.glIsEnabled) = undefined;
    var glDepthRange: FnPtr(function_signatures.glDepthRange) = undefined;
    var glViewport: FnPtr(function_signatures.glViewport) = undefined;
    var glDrawArrays: FnPtr(function_signatures.glDrawArrays) = undefined;
    var glDrawElements: FnPtr(function_signatures.glDrawElements) = undefined;
    var glPolygonOffset: FnPtr(function_signatures.glPolygonOffset) = undefined;
    var glCopyTexImage1D: FnPtr(function_signatures.glCopyTexImage1D) = undefined;
    var glCopyTexImage2D: FnPtr(function_signatures.glCopyTexImage2D) = undefined;
    var glCopyTexSubImage1D: FnPtr(function_signatures.glCopyTexSubImage1D) = undefined;
    var glCopyTexSubImage2D: FnPtr(function_signatures.glCopyTexSubImage2D) = undefined;
    var glTexSubImage1D: FnPtr(function_signatures.glTexSubImage1D) = undefined;
    var glTexSubImage2D: FnPtr(function_signatures.glTexSubImage2D) = undefined;
    var glBindTexture: FnPtr(function_signatures.glBindTexture) = undefined;
    var glDeleteTextures: FnPtr(function_signatures.glDeleteTextures) = undefined;
    var glGenTextures: FnPtr(function_signatures.glGenTextures) = undefined;
    var glIsTexture: FnPtr(function_signatures.glIsTexture) = undefined;
    var glDrawRangeElements: FnPtr(function_signatures.glDrawRangeElements) = undefined;
    var glTexImage3D: FnPtr(function_signatures.glTexImage3D) = undefined;
    var glTexSubImage3D: FnPtr(function_signatures.glTexSubImage3D) = undefined;
    var glCopyTexSubImage3D: FnPtr(function_signatures.glCopyTexSubImage3D) = undefined;
    var glActiveTexture: FnPtr(function_signatures.glActiveTexture) = undefined;
    var glSampleCoverage: FnPtr(function_signatures.glSampleCoverage) = undefined;
    var glCompressedTexImage3D: FnPtr(function_signatures.glCompressedTexImage3D) = undefined;
    var glCompressedTexImage2D: FnPtr(function_signatures.glCompressedTexImage2D) = undefined;
    var glCompressedTexImage1D: FnPtr(function_signatures.glCompressedTexImage1D) = undefined;
    var glCompressedTexSubImage3D: FnPtr(function_signatures.glCompressedTexSubImage3D) = undefined;
    var glCompressedTexSubImage2D: FnPtr(function_signatures.glCompressedTexSubImage2D) = undefined;
    var glCompressedTexSubImage1D: FnPtr(function_signatures.glCompressedTexSubImage1D) = undefined;
    var glGetCompressedTexImage: FnPtr(function_signatures.glGetCompressedTexImage) = undefined;
    var glVertexAttribP4uiv: FnPtr(function_signatures.glVertexAttribP4uiv) = undefined;
    var glVertexAttribP4ui: FnPtr(function_signatures.glVertexAttribP4ui) = undefined;
    var glVertexAttribP3uiv: FnPtr(function_signatures.glVertexAttribP3uiv) = undefined;
    var glVertexAttribP3ui: FnPtr(function_signatures.glVertexAttribP3ui) = undefined;
    var glVertexAttribP2uiv: FnPtr(function_signatures.glVertexAttribP2uiv) = undefined;
    var glVertexAttribP2ui: FnPtr(function_signatures.glVertexAttribP2ui) = undefined;
    var glVertexAttribP1uiv: FnPtr(function_signatures.glVertexAttribP1uiv) = undefined;
    var glVertexAttribP1ui: FnPtr(function_signatures.glVertexAttribP1ui) = undefined;
    var glVertexAttribDivisor: FnPtr(function_signatures.glVertexAttribDivisor) = undefined;
    var glGetQueryObjectui64v: FnPtr(function_signatures.glGetQueryObjectui64v) = undefined;
    var glGetQueryObjecti64v: FnPtr(function_signatures.glGetQueryObjecti64v) = undefined;
    var glQueryCounter: FnPtr(function_signatures.glQueryCounter) = undefined;
    var glGetSamplerParameterIuiv: FnPtr(function_signatures.glGetSamplerParameterIuiv) = undefined;
    var glGetSamplerParameterfv: FnPtr(function_signatures.glGetSamplerParameterfv) = undefined;
    var glGetSamplerParameterIiv: FnPtr(function_signatures.glGetSamplerParameterIiv) = undefined;
    var glGetSamplerParameteriv: FnPtr(function_signatures.glGetSamplerParameteriv) = undefined;
    var glSamplerParameterIuiv: FnPtr(function_signatures.glSamplerParameterIuiv) = undefined;
    var glSamplerParameterIiv: FnPtr(function_signatures.glSamplerParameterIiv) = undefined;
    var glSamplerParameterfv: FnPtr(function_signatures.glSamplerParameterfv) = undefined;
    var glSamplerParameterf: FnPtr(function_signatures.glSamplerParameterf) = undefined;
    var glSamplerParameteriv: FnPtr(function_signatures.glSamplerParameteriv) = undefined;
    var glSamplerParameteri: FnPtr(function_signatures.glSamplerParameteri) = undefined;
    var glBindSampler: FnPtr(function_signatures.glBindSampler) = undefined;
    var glIsSampler: FnPtr(function_signatures.glIsSampler) = undefined;
    var glDeleteSamplers: FnPtr(function_signatures.glDeleteSamplers) = undefined;
    var glGenSamplers: FnPtr(function_signatures.glGenSamplers) = undefined;
    var glGetFragDataIndex: FnPtr(function_signatures.glGetFragDataIndex) = undefined;
    var glBindFragDataLocationIndexed: FnPtr(function_signatures.glBindFragDataLocationIndexed) = undefined;
    var glSampleMaski: FnPtr(function_signatures.glSampleMaski) = undefined;
    var glGetMultisamplefv: FnPtr(function_signatures.glGetMultisamplefv) = undefined;
    var glTexImage3DMultisample: FnPtr(function_signatures.glTexImage3DMultisample) = undefined;
    var glTexImage2DMultisample: FnPtr(function_signatures.glTexImage2DMultisample) = undefined;
    var glFramebufferTexture: FnPtr(function_signatures.glFramebufferTexture) = undefined;
    var glGetBufferParameteri64v: FnPtr(function_signatures.glGetBufferParameteri64v) = undefined;
    var glBlendFuncSeparate: FnPtr(function_signatures.glBlendFuncSeparate) = undefined;
    var glMultiDrawArrays: FnPtr(function_signatures.glMultiDrawArrays) = undefined;
    var glMultiDrawElements: FnPtr(function_signatures.glMultiDrawElements) = undefined;
    var glPointParameterf: FnPtr(function_signatures.glPointParameterf) = undefined;
    var glPointParameterfv: FnPtr(function_signatures.glPointParameterfv) = undefined;
    var glPointParameteri: FnPtr(function_signatures.glPointParameteri) = undefined;
    var glPointParameteriv: FnPtr(function_signatures.glPointParameteriv) = undefined;
    var glGetInteger64i_v: FnPtr(function_signatures.glGetInteger64i_v) = undefined;
    var glGetSynciv: FnPtr(function_signatures.glGetSynciv) = undefined;
    var glGetInteger64v: FnPtr(function_signatures.glGetInteger64v) = undefined;
    var glWaitSync: FnPtr(function_signatures.glWaitSync) = undefined;
    var glClientWaitSync: FnPtr(function_signatures.glClientWaitSync) = undefined;
    var glDeleteSync: FnPtr(function_signatures.glDeleteSync) = undefined;
    var glIsSync: FnPtr(function_signatures.glIsSync) = undefined;
    var glFenceSync: FnPtr(function_signatures.glFenceSync) = undefined;
    var glBlendColor: FnPtr(function_signatures.glBlendColor) = undefined;
    var glBlendEquation: FnPtr(function_signatures.glBlendEquation) = undefined;
    var glProvokingVertex: FnPtr(function_signatures.glProvokingVertex) = undefined;
    var glMultiDrawElementsBaseVertex: FnPtr(function_signatures.glMultiDrawElementsBaseVertex) = undefined;
    var glDrawElementsInstancedBaseVertex: FnPtr(function_signatures.glDrawElementsInstancedBaseVertex) = undefined;
    var glDrawRangeElementsBaseVertex: FnPtr(function_signatures.glDrawRangeElementsBaseVertex) = undefined;
    var glDrawElementsBaseVertex: FnPtr(function_signatures.glDrawElementsBaseVertex) = undefined;
    var glGenQueries: FnPtr(function_signatures.glGenQueries) = undefined;
    var glDeleteQueries: FnPtr(function_signatures.glDeleteQueries) = undefined;
    var glIsQuery: FnPtr(function_signatures.glIsQuery) = undefined;
    var glBeginQuery: FnPtr(function_signatures.glBeginQuery) = undefined;
    var glEndQuery: FnPtr(function_signatures.glEndQuery) = undefined;
    var glGetQueryiv: FnPtr(function_signatures.glGetQueryiv) = undefined;
    var glGetQueryObjectiv: FnPtr(function_signatures.glGetQueryObjectiv) = undefined;
    var glGetQueryObjectuiv: FnPtr(function_signatures.glGetQueryObjectuiv) = undefined;
    var glBindBuffer: FnPtr(function_signatures.glBindBuffer) = undefined;
    var glDeleteBuffers: FnPtr(function_signatures.glDeleteBuffers) = undefined;
    var glGenBuffers: FnPtr(function_signatures.glGenBuffers) = undefined;
    var glIsBuffer: FnPtr(function_signatures.glIsBuffer) = undefined;
    var glBufferData: FnPtr(function_signatures.glBufferData) = undefined;
    var glBufferSubData: FnPtr(function_signatures.glBufferSubData) = undefined;
    var glGetBufferSubData: FnPtr(function_signatures.glGetBufferSubData) = undefined;
    var glMapBuffer: FnPtr(function_signatures.glMapBuffer) = undefined;
    var glUnmapBuffer: FnPtr(function_signatures.glUnmapBuffer) = undefined;
    var glGetBufferParameteriv: FnPtr(function_signatures.glGetBufferParameteriv) = undefined;
    var glGetBufferPointerv: FnPtr(function_signatures.glGetBufferPointerv) = undefined;
    var glBlendEquationSeparate: FnPtr(function_signatures.glBlendEquationSeparate) = undefined;
    var glDrawBuffers: FnPtr(function_signatures.glDrawBuffers) = undefined;
    var glStencilOpSeparate: FnPtr(function_signatures.glStencilOpSeparate) = undefined;
    var glStencilFuncSeparate: FnPtr(function_signatures.glStencilFuncSeparate) = undefined;
    var glStencilMaskSeparate: FnPtr(function_signatures.glStencilMaskSeparate) = undefined;
    var glAttachShader: FnPtr(function_signatures.glAttachShader) = undefined;
    var glBindAttribLocation: FnPtr(function_signatures.glBindAttribLocation) = undefined;
    var glCompileShader: FnPtr(function_signatures.glCompileShader) = undefined;
    var glCreateProgram: FnPtr(function_signatures.glCreateProgram) = undefined;
    var glCreateShader: FnPtr(function_signatures.glCreateShader) = undefined;
    var glDeleteProgram: FnPtr(function_signatures.glDeleteProgram) = undefined;
    var glDeleteShader: FnPtr(function_signatures.glDeleteShader) = undefined;
    var glDetachShader: FnPtr(function_signatures.glDetachShader) = undefined;
    var glDisableVertexAttribArray: FnPtr(function_signatures.glDisableVertexAttribArray) = undefined;
    var glEnableVertexAttribArray: FnPtr(function_signatures.glEnableVertexAttribArray) = undefined;
    var glGetActiveAttrib: FnPtr(function_signatures.glGetActiveAttrib) = undefined;
    var glGetActiveUniform: FnPtr(function_signatures.glGetActiveUniform) = undefined;
    var glGetAttachedShaders: FnPtr(function_signatures.glGetAttachedShaders) = undefined;
    var glGetAttribLocation: FnPtr(function_signatures.glGetAttribLocation) = undefined;
    var glGetProgramiv: FnPtr(function_signatures.glGetProgramiv) = undefined;
    var glGetProgramInfoLog: FnPtr(function_signatures.glGetProgramInfoLog) = undefined;
    var glGetShaderiv: FnPtr(function_signatures.glGetShaderiv) = undefined;
    var glGetShaderInfoLog: FnPtr(function_signatures.glGetShaderInfoLog) = undefined;
    var glGetShaderSource: FnPtr(function_signatures.glGetShaderSource) = undefined;
    var glGetUniformLocation: FnPtr(function_signatures.glGetUniformLocation) = undefined;
    var glGetUniformfv: FnPtr(function_signatures.glGetUniformfv) = undefined;
    var glGetUniformiv: FnPtr(function_signatures.glGetUniformiv) = undefined;
    var glGetVertexAttribdv: FnPtr(function_signatures.glGetVertexAttribdv) = undefined;
    var glGetVertexAttribfv: FnPtr(function_signatures.glGetVertexAttribfv) = undefined;
    var glGetVertexAttribiv: FnPtr(function_signatures.glGetVertexAttribiv) = undefined;
    var glGetVertexAttribPointerv: FnPtr(function_signatures.glGetVertexAttribPointerv) = undefined;
    var glIsProgram: FnPtr(function_signatures.glIsProgram) = undefined;
    var glIsShader: FnPtr(function_signatures.glIsShader) = undefined;
    var glLinkProgram: FnPtr(function_signatures.glLinkProgram) = undefined;
    var glShaderSource: FnPtr(function_signatures.glShaderSource) = undefined;
    var glUseProgram: FnPtr(function_signatures.glUseProgram) = undefined;
    var glUniform1f: FnPtr(function_signatures.glUniform1f) = undefined;
    var glUniform2f: FnPtr(function_signatures.glUniform2f) = undefined;
    var glUniform3f: FnPtr(function_signatures.glUniform3f) = undefined;
    var glUniform4f: FnPtr(function_signatures.glUniform4f) = undefined;
    var glUniform1i: FnPtr(function_signatures.glUniform1i) = undefined;
    var glUniform2i: FnPtr(function_signatures.glUniform2i) = undefined;
    var glUniform3i: FnPtr(function_signatures.glUniform3i) = undefined;
    var glUniform4i: FnPtr(function_signatures.glUniform4i) = undefined;
    var glUniform1fv: FnPtr(function_signatures.glUniform1fv) = undefined;
    var glUniform2fv: FnPtr(function_signatures.glUniform2fv) = undefined;
    var glUniform3fv: FnPtr(function_signatures.glUniform3fv) = undefined;
    var glUniform4fv: FnPtr(function_signatures.glUniform4fv) = undefined;
    var glUniform1iv: FnPtr(function_signatures.glUniform1iv) = undefined;
    var glUniform2iv: FnPtr(function_signatures.glUniform2iv) = undefined;
    var glUniform3iv: FnPtr(function_signatures.glUniform3iv) = undefined;
    var glUniform4iv: FnPtr(function_signatures.glUniform4iv) = undefined;
    var glUniformMatrix2fv: FnPtr(function_signatures.glUniformMatrix2fv) = undefined;
    var glUniformMatrix3fv: FnPtr(function_signatures.glUniformMatrix3fv) = undefined;
    var glUniformMatrix4fv: FnPtr(function_signatures.glUniformMatrix4fv) = undefined;
    var glValidateProgram: FnPtr(function_signatures.glValidateProgram) = undefined;
    var glVertexAttrib1d: FnPtr(function_signatures.glVertexAttrib1d) = undefined;
    var glVertexAttrib1dv: FnPtr(function_signatures.glVertexAttrib1dv) = undefined;
    var glVertexAttrib1f: FnPtr(function_signatures.glVertexAttrib1f) = undefined;
    var glVertexAttrib1fv: FnPtr(function_signatures.glVertexAttrib1fv) = undefined;
    var glVertexAttrib1s: FnPtr(function_signatures.glVertexAttrib1s) = undefined;
    var glVertexAttrib1sv: FnPtr(function_signatures.glVertexAttrib1sv) = undefined;
    var glVertexAttrib2d: FnPtr(function_signatures.glVertexAttrib2d) = undefined;
    var glVertexAttrib2dv: FnPtr(function_signatures.glVertexAttrib2dv) = undefined;
    var glVertexAttrib2f: FnPtr(function_signatures.glVertexAttrib2f) = undefined;
    var glVertexAttrib2fv: FnPtr(function_signatures.glVertexAttrib2fv) = undefined;
    var glVertexAttrib2s: FnPtr(function_signatures.glVertexAttrib2s) = undefined;
    var glVertexAttrib2sv: FnPtr(function_signatures.glVertexAttrib2sv) = undefined;
    var glVertexAttrib3d: FnPtr(function_signatures.glVertexAttrib3d) = undefined;
    var glVertexAttrib3dv: FnPtr(function_signatures.glVertexAttrib3dv) = undefined;
    var glVertexAttrib3f: FnPtr(function_signatures.glVertexAttrib3f) = undefined;
    var glVertexAttrib3fv: FnPtr(function_signatures.glVertexAttrib3fv) = undefined;
    var glVertexAttrib3s: FnPtr(function_signatures.glVertexAttrib3s) = undefined;
    var glVertexAttrib3sv: FnPtr(function_signatures.glVertexAttrib3sv) = undefined;
    var glVertexAttrib4Nbv: FnPtr(function_signatures.glVertexAttrib4Nbv) = undefined;
    var glVertexAttrib4Niv: FnPtr(function_signatures.glVertexAttrib4Niv) = undefined;
    var glVertexAttrib4Nsv: FnPtr(function_signatures.glVertexAttrib4Nsv) = undefined;
    var glVertexAttrib4Nub: FnPtr(function_signatures.glVertexAttrib4Nub) = undefined;
    var glVertexAttrib4Nubv: FnPtr(function_signatures.glVertexAttrib4Nubv) = undefined;
    var glVertexAttrib4Nuiv: FnPtr(function_signatures.glVertexAttrib4Nuiv) = undefined;
    var glVertexAttrib4Nusv: FnPtr(function_signatures.glVertexAttrib4Nusv) = undefined;
    var glVertexAttrib4bv: FnPtr(function_signatures.glVertexAttrib4bv) = undefined;
    var glVertexAttrib4d: FnPtr(function_signatures.glVertexAttrib4d) = undefined;
    var glVertexAttrib4dv: FnPtr(function_signatures.glVertexAttrib4dv) = undefined;
    var glVertexAttrib4f: FnPtr(function_signatures.glVertexAttrib4f) = undefined;
    var glVertexAttrib4fv: FnPtr(function_signatures.glVertexAttrib4fv) = undefined;
    var glVertexAttrib4iv: FnPtr(function_signatures.glVertexAttrib4iv) = undefined;
    var glVertexAttrib4s: FnPtr(function_signatures.glVertexAttrib4s) = undefined;
    var glVertexAttrib4sv: FnPtr(function_signatures.glVertexAttrib4sv) = undefined;
    var glVertexAttrib4ubv: FnPtr(function_signatures.glVertexAttrib4ubv) = undefined;
    var glVertexAttrib4uiv: FnPtr(function_signatures.glVertexAttrib4uiv) = undefined;
    var glVertexAttrib4usv: FnPtr(function_signatures.glVertexAttrib4usv) = undefined;
    var glVertexAttribPointer: FnPtr(function_signatures.glVertexAttribPointer) = undefined;
    var glUniformMatrix2x3fv: FnPtr(function_signatures.glUniformMatrix2x3fv) = undefined;
    var glUniformMatrix3x2fv: FnPtr(function_signatures.glUniformMatrix3x2fv) = undefined;
    var glUniformMatrix2x4fv: FnPtr(function_signatures.glUniformMatrix2x4fv) = undefined;
    var glUniformMatrix4x2fv: FnPtr(function_signatures.glUniformMatrix4x2fv) = undefined;
    var glUniformMatrix3x4fv: FnPtr(function_signatures.glUniformMatrix3x4fv) = undefined;
    var glUniformMatrix4x3fv: FnPtr(function_signatures.glUniformMatrix4x3fv) = undefined;
    var glColorMaski: FnPtr(function_signatures.glColorMaski) = undefined;
    var glGetBooleani_v: FnPtr(function_signatures.glGetBooleani_v) = undefined;
    var glGetIntegeri_v: FnPtr(function_signatures.glGetIntegeri_v) = undefined;
    var glEnablei: FnPtr(function_signatures.glEnablei) = undefined;
    var glDisablei: FnPtr(function_signatures.glDisablei) = undefined;
    var glIsEnabledi: FnPtr(function_signatures.glIsEnabledi) = undefined;
    var glBeginTransformFeedback: FnPtr(function_signatures.glBeginTransformFeedback) = undefined;
    var glEndTransformFeedback: FnPtr(function_signatures.glEndTransformFeedback) = undefined;
    var glBindBufferRange: FnPtr(function_signatures.glBindBufferRange) = undefined;
    var glBindBufferBase: FnPtr(function_signatures.glBindBufferBase) = undefined;
    var glTransformFeedbackVaryings: FnPtr(function_signatures.glTransformFeedbackVaryings) = undefined;
    var glGetTransformFeedbackVarying: FnPtr(function_signatures.glGetTransformFeedbackVarying) = undefined;
    var glClampColor: FnPtr(function_signatures.glClampColor) = undefined;
    var glBeginConditionalRender: FnPtr(function_signatures.glBeginConditionalRender) = undefined;
    var glEndConditionalRender: FnPtr(function_signatures.glEndConditionalRender) = undefined;
    var glVertexAttribIPointer: FnPtr(function_signatures.glVertexAttribIPointer) = undefined;
    var glGetVertexAttribIiv: FnPtr(function_signatures.glGetVertexAttribIiv) = undefined;
    var glGetVertexAttribIuiv: FnPtr(function_signatures.glGetVertexAttribIuiv) = undefined;
    var glVertexAttribI1i: FnPtr(function_signatures.glVertexAttribI1i) = undefined;
    var glVertexAttribI2i: FnPtr(function_signatures.glVertexAttribI2i) = undefined;
    var glVertexAttribI3i: FnPtr(function_signatures.glVertexAttribI3i) = undefined;
    var glVertexAttribI4i: FnPtr(function_signatures.glVertexAttribI4i) = undefined;
    var glVertexAttribI1ui: FnPtr(function_signatures.glVertexAttribI1ui) = undefined;
    var glVertexAttribI2ui: FnPtr(function_signatures.glVertexAttribI2ui) = undefined;
    var glVertexAttribI3ui: FnPtr(function_signatures.glVertexAttribI3ui) = undefined;
    var glVertexAttribI4ui: FnPtr(function_signatures.glVertexAttribI4ui) = undefined;
    var glVertexAttribI1iv: FnPtr(function_signatures.glVertexAttribI1iv) = undefined;
    var glVertexAttribI2iv: FnPtr(function_signatures.glVertexAttribI2iv) = undefined;
    var glVertexAttribI3iv: FnPtr(function_signatures.glVertexAttribI3iv) = undefined;
    var glVertexAttribI4iv: FnPtr(function_signatures.glVertexAttribI4iv) = undefined;
    var glVertexAttribI1uiv: FnPtr(function_signatures.glVertexAttribI1uiv) = undefined;
    var glVertexAttribI2uiv: FnPtr(function_signatures.glVertexAttribI2uiv) = undefined;
    var glVertexAttribI3uiv: FnPtr(function_signatures.glVertexAttribI3uiv) = undefined;
    var glVertexAttribI4uiv: FnPtr(function_signatures.glVertexAttribI4uiv) = undefined;
    var glVertexAttribI4bv: FnPtr(function_signatures.glVertexAttribI4bv) = undefined;
    var glVertexAttribI4sv: FnPtr(function_signatures.glVertexAttribI4sv) = undefined;
    var glVertexAttribI4ubv: FnPtr(function_signatures.glVertexAttribI4ubv) = undefined;
    var glVertexAttribI4usv: FnPtr(function_signatures.glVertexAttribI4usv) = undefined;
    var glGetUniformuiv: FnPtr(function_signatures.glGetUniformuiv) = undefined;
    var glBindFragDataLocation: FnPtr(function_signatures.glBindFragDataLocation) = undefined;
    var glGetFragDataLocation: FnPtr(function_signatures.glGetFragDataLocation) = undefined;
    var glUniform1ui: FnPtr(function_signatures.glUniform1ui) = undefined;
    var glUniform2ui: FnPtr(function_signatures.glUniform2ui) = undefined;
    var glUniform3ui: FnPtr(function_signatures.glUniform3ui) = undefined;
    var glUniform4ui: FnPtr(function_signatures.glUniform4ui) = undefined;
    var glUniform1uiv: FnPtr(function_signatures.glUniform1uiv) = undefined;
    var glUniform2uiv: FnPtr(function_signatures.glUniform2uiv) = undefined;
    var glUniform3uiv: FnPtr(function_signatures.glUniform3uiv) = undefined;
    var glUniform4uiv: FnPtr(function_signatures.glUniform4uiv) = undefined;
    var glTexParameterIiv: FnPtr(function_signatures.glTexParameterIiv) = undefined;
    var glTexParameterIuiv: FnPtr(function_signatures.glTexParameterIuiv) = undefined;
    var glGetTexParameterIiv: FnPtr(function_signatures.glGetTexParameterIiv) = undefined;
    var glGetTexParameterIuiv: FnPtr(function_signatures.glGetTexParameterIuiv) = undefined;
    var glClearBufferiv: FnPtr(function_signatures.glClearBufferiv) = undefined;
    var glClearBufferuiv: FnPtr(function_signatures.glClearBufferuiv) = undefined;
    var glClearBufferfv: FnPtr(function_signatures.glClearBufferfv) = undefined;
    var glClearBufferfi: FnPtr(function_signatures.glClearBufferfi) = undefined;
    var glGetStringi: FnPtr(function_signatures.glGetStringi) = undefined;
    var glIsRenderbuffer: FnPtr(function_signatures.glIsRenderbuffer) = undefined;
    var glBindRenderbuffer: FnPtr(function_signatures.glBindRenderbuffer) = undefined;
    var glDeleteRenderbuffers: FnPtr(function_signatures.glDeleteRenderbuffers) = undefined;
    var glGenRenderbuffers: FnPtr(function_signatures.glGenRenderbuffers) = undefined;
    var glRenderbufferStorage: FnPtr(function_signatures.glRenderbufferStorage) = undefined;
    var glGetRenderbufferParameteriv: FnPtr(function_signatures.glGetRenderbufferParameteriv) = undefined;
    var glIsFramebuffer: FnPtr(function_signatures.glIsFramebuffer) = undefined;
    var glBindFramebuffer: FnPtr(function_signatures.glBindFramebuffer) = undefined;
    var glDeleteFramebuffers: FnPtr(function_signatures.glDeleteFramebuffers) = undefined;
    var glGenFramebuffers: FnPtr(function_signatures.glGenFramebuffers) = undefined;
    var glCheckFramebufferStatus: FnPtr(function_signatures.glCheckFramebufferStatus) = undefined;
    var glFramebufferTexture1D: FnPtr(function_signatures.glFramebufferTexture1D) = undefined;
    var glFramebufferTexture2D: FnPtr(function_signatures.glFramebufferTexture2D) = undefined;
    var glFramebufferTexture3D: FnPtr(function_signatures.glFramebufferTexture3D) = undefined;
    var glFramebufferRenderbuffer: FnPtr(function_signatures.glFramebufferRenderbuffer) = undefined;
    var glGetFramebufferAttachmentParameteriv: FnPtr(function_signatures.glGetFramebufferAttachmentParameteriv) = undefined;
    var glGenerateMipmap: FnPtr(function_signatures.glGenerateMipmap) = undefined;
    var glBlitFramebuffer: FnPtr(function_signatures.glBlitFramebuffer) = undefined;
    var glRenderbufferStorageMultisample: FnPtr(function_signatures.glRenderbufferStorageMultisample) = undefined;
    var glFramebufferTextureLayer: FnPtr(function_signatures.glFramebufferTextureLayer) = undefined;
    var glMapBufferRange: FnPtr(function_signatures.glMapBufferRange) = undefined;
    var glFlushMappedBufferRange: FnPtr(function_signatures.glFlushMappedBufferRange) = undefined;
    var glBindVertexArray: FnPtr(function_signatures.glBindVertexArray) = undefined;
    var glDeleteVertexArrays: FnPtr(function_signatures.glDeleteVertexArrays) = undefined;
    var glGenVertexArrays: FnPtr(function_signatures.glGenVertexArrays) = undefined;
    var glIsVertexArray: FnPtr(function_signatures.glIsVertexArray) = undefined;
    var glDrawArraysInstanced: FnPtr(function_signatures.glDrawArraysInstanced) = undefined;
    var glDrawElementsInstanced: FnPtr(function_signatures.glDrawElementsInstanced) = undefined;
    var glTexBuffer: FnPtr(function_signatures.glTexBuffer) = undefined;
    var glPrimitiveRestartIndex: FnPtr(function_signatures.glPrimitiveRestartIndex) = undefined;
    var glCopyBufferSubData: FnPtr(function_signatures.glCopyBufferSubData) = undefined;
    var glGetUniformIndices: FnPtr(function_signatures.glGetUniformIndices) = undefined;
    var glGetActiveUniformsiv: FnPtr(function_signatures.glGetActiveUniformsiv) = undefined;
    var glGetActiveUniformName: FnPtr(function_signatures.glGetActiveUniformName) = undefined;
    var glGetUniformBlockIndex: FnPtr(function_signatures.glGetUniformBlockIndex) = undefined;
    var glGetActiveUniformBlockiv: FnPtr(function_signatures.glGetActiveUniformBlockiv) = undefined;
    var glGetActiveUniformBlockName: FnPtr(function_signatures.glGetActiveUniformBlockName) = undefined;
    var glUniformBlockBinding: FnPtr(function_signatures.glUniformBlockBinding) = undefined;
};

test {
    _ = load;
    @setEvalBranchQuota(100_000); // Yes, this is necessary. OpenGL gets quite large!
    std.testing.refAllDecls(@This());
}
