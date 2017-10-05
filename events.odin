Key :: enum {
	UP,
	DOWN,
	LEFT,
	RIGHT,
}

QuitEvent :: struct {};
KeyEvent :: struct {
	down: bool,
	repeat: bool,
	key: Key,
};

Event :: union {
	QuitEvent,
	KeyEvent,
}

// returns true if there are more events in the queue
/*get_event :: proc() -> Event, bool = true {
	
}*/