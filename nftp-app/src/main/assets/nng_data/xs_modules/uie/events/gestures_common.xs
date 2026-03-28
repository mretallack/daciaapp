export enum GesturePhase {
	Possible = 0,    // gesture isn't recognized, but it's possible that it will be 
	Began = 1,       // gesture recognized first time
	InProgress,      // gesture is continous, it's beeing recognized in succession
	Ended,		     // continous gesture recog ended -> only use in events ? no data is valid

	// touch events won't be dispatched to recognizers in phases below
	PhaseRecognised,      // gesture is simple -> it's been recognized, won't be recognized again
	PhaseFailed,           // gesture can't be recognized in this session anymore
}