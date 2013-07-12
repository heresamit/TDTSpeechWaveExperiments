TDTSpeechWaveExperiments
========================

A repository that aims to explore possible methods for displaying a speech wave while recording and playing an audio file to be used in a push to talk functionality later on.

This project uses two methods to display waves corresponding to audio being recorded and played.
The two different methods are implemented in 1) TDTPushToTalkRecorderViewController and 2) TDTPushToTalkSimplerVC respectively.

The first method is a fairly complex one, it also consumes more memory and therefore is not recommended. It does offer more control on the other hand.
However for the simple purpose of drawing a wave based only on the audio's amplitude (~Average Power), the second method suffices.

The first method is based on Apple's sample project named SpeakHere. It uses Objective-c++ code and some c++ helpers provided by apple.
It is based on the coreAudio framework.

The second method is based simply on the higher level implementations AVAudioPlayer and AVAudioRecorder. Both these methods get the average power and send an corresponding value 
to a waveView which uses this information about the amplitude to display a wave.

Again, two types of wave views are available: TDTWaveView and TDTAudioWaveView. The user can change wave behaviors easily by modifying some factors in both the views.

Finally, to the appearance.
The app opens up with a Tab Bar. First Tab uses the first method, second tab uses the easier, more preferred second method. 

Within the tabs you can see different types of waves using a segmented Control.
Audio wave drawing during play is implemented only for the second method.
Press and hold the button to record, press play to play the sound, in the first method, it plays automatically.
