#  Pro-Tips for Tuning On-Device LLMs
Since you are developing for a mobile device with a fixed 4GB memory pool, keep these best practices in mind:
- Context Window Truncation: As conversations grow longer, the model tracks more tokens in its memory buffer. It is a good idea to limit messages to the last 10–15 exchanges to prevent the app from lagging or getting terminated by iOS memory management.
- Temperature Calibration: In your container.generate call, the temperature: 0.7 argument balances creativity and accuracy. If the model types gibberish, turn it down to 0.2. If it feels too robotic, turn it up to 0.8.
Feel free to edit the parameters.🙂
