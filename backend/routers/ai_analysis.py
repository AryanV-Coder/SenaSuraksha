import google.generativeai as genai
import os
from dotenv import load_dotenv
import base64
from fastapi import APIRouter, UploadFile, File
from fastapi.responses import FileResponse, StreamingResponse
import speech_recognition as sr
from pydub import AudioSegment
from gtts import gTTS

load_dotenv()

router = APIRouter()

genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
model = genai.GenerativeModel("gemini-2.5-flash")

def text_to_speech(text, filename="response.mp3"):
    """Convert text to speech using gTTS"""
    try:
        tts = gTTS(text=text, lang='en', slow=False)
        audio_path = f"generated_audio/{filename}"
        os.makedirs("generated_audio", exist_ok=True)
        tts.save(audio_path)
        return audio_path
    except Exception as e:
        print(f"Error converting text to speech: {e}")
        return None

def speech_to_text(audio_path):
    # 🎧 Convert to 16kHz mono WAV for transcription
    audio = AudioSegment.from_file(audio_path, format="aac")
    audio = audio.set_channels(1).set_frame_rate(16000)
    audio.export(audio_path, format="wav")
    print("[✅] Converted audio to proper format")

    recognizer = sr.Recognizer()
    with sr.AudioFile(audio_path) as source:
        audio_data = recognizer.record(source)
    try:
        text = recognizer.recognize_google(audio_data)
    except sr.UnknownValueError:
        text = None
    return text

@router.post("/soldier-feed")  # Should be POST for file uploads
async def soldier_feed(video: UploadFile = File(None), audio: UploadFile = File(None)):

    if video is not None and audio is None:
        # # Ensure directory exists
        # os.makedirs("uploaded_videos", exist_ok=True)
        
        # # Save video file (convert .temp to .mp4 if needed)
        # filename = video.filename
        # if filename.endswith('.temp'):
        #     filename = filename.rsplit('.', 1)[0] + '.mp4'
        # video_file_path = f"uploaded_videos/{filename}"
        # contents = await video.read()
        # with open(video_file_path, "wb") as file:
        #     file.write(contents)

        # # Read the binary data and encode to base64
        # with open(video_file_path, 'rb') as file:
        #     encoded_video = base64.b64encode(file.read()).decode('utf-8')

        contents = await video.read()
        encoded_video = base64.b64encode(contents).decode('utf-8')


        prompt =[
            {
                "role": "user",
                "parts": [
                    {
                        "text": (
                            "You are an AI Tactical Assistant.\n"
                            "Based on the attached 360° surveillance video from a soldier's helmet cam "
                            "and their current location, analyze the surroundings for:\n"
                            "- Potential threats\n"
                            "- Visibility and line of sight\n"
                            "- Terrain advantages\n"
                            "\nSuggest immediate tactical actions including:\n"
                            "- Best direction to move\n"
                            "- Where to hide or take cover\n"
                            "- Whether to hold position or relocate\n"
                            "\nUse clear, concise, military-style instructions suitable for real-time combat support."
                        )
                    }
                ]
            },
            {
                "role": "user",
                "parts": [
                    {
                        "mime_type": "video/mp4",
                        "data": encoded_video  # Your base64 string here
                    }
                ]
            }
        ]

    elif audio is not None and video is None:
        # Ensure directory exists
        os.makedirs("uploaded_audios", exist_ok=True)

        # Save audio file (convert .aac to .wav if needed)
        filename = audio.filename
        if filename.endswith('.aac'):
            filename = filename.rsplit('.', 1)[0] + '.mp3'
        audio_file_path = f"uploaded_audios/{filename}"
        contents = await audio.read()
        with open(audio_file_path, "wb") as file:
            file.write(contents)
        
        soldier_input = speech_to_text(audio_file_path)

        if soldier_input is None:
            response_audio_path = text_to_speech("Unable to understand audio !!","error_response.mp3")
            return StreamingResponse(open(response_audio_path, "rb"), media_type="audio/mpeg")

        prompt = [
            {
                "role": "user",
                "parts": [
                    {
                        "text": (
                            "You are an AI Tactical Assistant for Indian soldiers in combat.\n"
                            "Interpret the following situation described by the soldier.\n"
                            "Give immediate tactical suggestions in bullet points using military tone.\n"
                            "Be concise, practical, and helpful for decision-making under pressure.\n"
                            "Here is the soldier’s prompt:\n\n"
                            f"{soldier_input}"
                        )
                    }
                ]
            }
        ]

    elif (video is not None and audio is not None):
        # Ensure directories exist
        # os.makedirs("uploaded_videos", exist_ok=True)
        os.makedirs("uploaded_audios", exist_ok=True)
        
        # # Save video file (convert .temp to .mp4 if needed)
        # filename = video.filename
        # if filename.endswith('.temp'):
        #     filename = filename.rsplit('.', 1)[0] + '.mp4'
        # video_file_path = f"uploaded_videos/{filename}"
        # contents = await video.read()
        # with open(video_file_path, "wb") as file:
        #     file.write(contents)

        # # Read the binary data and encode to base64
        # with open(video_file_path, 'rb') as file:
        #     encoded_video = base64.b64encode(file.read()).decode('utf-8')

        contents = await video.read()
        encoded_video = base64.b64encode(contents).decode('utf-8')

        # Save audio file (convert .aac to .wav if needed)
        filename = audio.filename
        if filename.endswith('.aac'):
            filename = filename.rsplit('.', 1)[0] + '.mp3'
        audio_file_path = f"uploaded_audios/{filename}"
        contents = await audio.read()
        with open(audio_file_path, "wb") as file:
            file.write(contents)
        
        soldier_input = speech_to_text(audio_file_path)

        prompt = [
            {
                "role": "user",
                "parts": [
                    {
                        "text": (
                            "You are an AI Tactical Assistant deployed in active combat scenarios.\n"
                            "The following situation comes from an Indian soldier in the field.\n\n"
                            "First, analyze the attached 360° helmet cam video for threats, obstacles, possible hiding spots, or ambush zones.\n"
                            "Then, consider the soldier's message to understand intent, emotional state, or strategic request.\n\n"
                            "Provide the following in response:\n"
                            "1. Immediate tactical advice (movement, cover, actions)\n"
                            "2. Threat assessment (environmental, enemy presence, visibility)\n"
                            "3. Terrain recommendations (high ground, fallback points, danger zones)\n\n"
                            "Be concise, clear, and use military-style suggestions.\n\n"
                            "👤 Soldier's Message:\n"
                            f"{soldier_input}"
                        )
                    }
                ]
            },
            {
                "role": "user",
                "parts": [
                    {
                        "mime_type": "video/mp4",
                        "data": encoded_video  # Base64 video string
                    }
                ]
            }
        ]
    
    else:
        # Both video and audio are None
        response_audio_path = text_to_speech("Unable to understand audio !!","error_response.mp3")
        return StreamingResponse(open(response_audio_path, "rb"), media_type="audio/mpeg")

    # Generate AI response
    response = model.generate_content(prompt)

    # Convert response to audio
    response_audio_path = text_to_speech(response.text)
    
    if response_audio_path:
        return StreamingResponse(open(response_audio_path, "rb"), media_type="audio/mpeg")
    else:
        response_audio_path = text_to_speech("Unable to understand audio !!","error_response.mp3")
        return StreamingResponse(open(response_audio_path, "rb"), media_type="audio/mpeg")

    # # Save response in markdown format to a file
    # with open("video_analysis_response.md", "w") as f:
    #     f.write(response.text)

    # # Optionally, print a message to confirm
    # print("Response saved to video_analysis_response.md")