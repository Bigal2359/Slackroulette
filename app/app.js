const { App, ExpressReceiver } = require('@slack/bolt');

const receiver = new ExpressReceiver({
  signingSecret: process.env.SLACK_SIGNING_SECRET
});


// Initializes your app with your bot token and signing secret
const app = new App({
  token: process.env.SLACK_BOT_TOKEN,
  signingSecret: process.env.SLACK_SIGNING_SECRET,
  receiver: receiver
});

let callerID;
let receiverID;
let chatID;
let botTokenContext;
let spinChannelID;
let spinTS;

receiver.app.get('/healthcheck', (_, res) => {
  res.status(200).send(); // respond 200 OK to the default health check method
});

// Listen to the app_home_opened Events API event to hear when a user opens your app from the sidebar
app.event("app_home_opened", async ({ payload, context }) => {
  const userId = payload.user;
  
  try {
    // Call the views.publish method using the built-in WebClient
    const result = await app.client.views.publish({
      // The token you used to initialize your app is stored in the `context` object
      token: context.botToken,
      user_id: userId,
      view: {
        // Home tabs must be enabled in your app configuration page under "App Home"
        "type": "home",
        "blocks": [
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": "*Welcome to the Slackroulette home, <@" + userId + "> :house:*"
            }
          },
          {
            "type": "divider"
          },
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": "Slackroulette helps you randomly find and talk to members of your FCBNY team, including the ones you haven't met yet. You can request a Slackroulette session or you can respond to a request by joining a session in the #slackroulette-wheel channel."
            }
          },
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": "Type *`/slackroulette`* on any message field in the FCBNY Workspace to start a Slackroulette session"
            }
          },
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": "OR"
            }
          },
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": "Click the button below to spin the Slackroulette wheel."
            }
          },
          {
            "type": "actions",
            "elements": [
              {
                "type": "button",
                "text": {
                  "type": "plain_text",
                  "text": "Spin the Wheel"
                },
                "action_id": "spin_wheel"
              }
            ]
          }
        ]
      }
    });

    console.log(result);
  }
  catch (error) {
    console.error(error);
  }
});

// The slackroulette command starts a Slackroulette session

app.command('/slackroulette', async ({ command, ack, respond, payload }) => {
  // Acknowledge command request
  await ack();

  // await respond("You're starting a Slackroulette session!");
  await respond({

    text: "You're about to start a Slackroulette session!",
    blocks: [

      {
        "type": "section",
        "text": {
          "type": "mrkdwn",
          "text": "You're about to start a Slackroulette session!"
        }
      },
      {
        "type": "actions",
        "elements": [
          {
            "type": "button",
            "text": {
              "type": "plain_text",
              "text": "Spin the Wheel"
            },
            "action_id": "spin_wheel"
          }
        ]
      }
    ]
  });

  console.log(payload);
});
 

app.action('spin_wheel', async ({ ack, body, payload, context }) => {
  // Acknowledge the action
  await ack();

  try {
    // Call the chat.postMessage method using the built-in WebClient
    const result = await app.client.chat.postMessage({
      // The token you used to initialize your app is stored in the `context` object
      token: context.botToken,
      // Payload message should be posted in the channel where original message was heard
      channel: "slackroulette-wheel",
      text: "An FCBuddy has requested a Slackroulette session! The first person to click 'Join' will be added to the session.",
      blocks: [

        {
          "type": "section",
          "text": {
            "type": "mrkdwn",
            "text": `An FCBuddy has requested a Slackroulette session! The first person to click Join will be added to the session.`
          }
        },
        {
          "type": "actions",
          "elements": [
            {
              "type": "button",
              "text": {
                "type": "plain_text",
                "text": "Join"
              },
              "action_id": "wheel_stop"
            }
          ]
        }
      ]
    });

    spinChannelID = result.channel;
    spinTS = result.ts;
    callerID = body.user.id;
    console.log('The Caller ID is set to ' + callerID);
    console.log()
    console.log(result);
  }
  catch (error) {
    console.error(error);
  }
});

app.action('wheel_stop', async ({ ack, context, body }) => {
  // Acknowledge the action
  await ack();

  receiverID = body.user.id;

  try {
    // Call the conversations.create method using the built-in WebClient
    const result = await app.client.conversations.open({
      // The token you used to initialize your app is stored in the `context` object
      token: context.botToken,
      users: `${callerID}, ${receiverID}`
    });

    botTokenContext = context.botToken;
    chatID = result.channel.id;
    console.log(result);
    startChat();
    updateChat(botTokenContext, spinChannelID, spinTS);
  }
  catch (error) {
    console.error(error);
  }
});

async function updateCommandMsg() {

  try {
    // Call the chat.postMessage method using the built-in WebClient
    const result = await app.client.chat.update({
      // The token you used to initialize your app is stored in the `context` object
      token: botTokenContext,
      // Payload message should be posted in the channel where original message was heard
      channel: spinChannelID,
      ts: spinTS,
      as_user: true,
      text: "Your Slackroulette request has been sent!"
    });

    console.log(result);
  }
  catch (error) {
    console.error(error);
  }
}

async function startChat() {

  try {
    // Call the chat.postMessage method using the built-in WebClient
    const result = await app.client.chat.postMessage({
      // The token you used to initialize your app is stored in the `context` object
      token: botTokenContext,
      channel: chatID,
      text: "👋 Welcome to the start of your Slackroulette session!",
      blocks: [
        {
          "type": "section",
          "text": {
            "type": "mrkdwn",
            "text": `:wave: <@${callerID}>, <@${receiverID}>\nThank you for spinning the Slackroulette wheel!`
          }
        },
        {
          "type": "section",
          "text": {
            "type": "mrkdwn",
            "text": "1️⃣ Start chatting and get to know each other better"
          }
        },
        {
          "type": "section",
          "text": {
            "type": "mrkdwn",
            "text": "OR"
          }
        },
        {
          "type": "section",
          "text": {
            "type": "mrkdwn",
            "text": "2️⃣ Type *`/call`* to start a Slack call"
          }
        },
        {
          "type": "section",
          "text": {
            "type": "mrkdwn",
            "text": "Enjoy!"
          }
        }
      ]
    });

    console.log(result);
  }
  catch (error) {
    console.error(error);
  }
}

async function updateChat(botTokenContext, spinChannelID, spinTS) {

  try {
    // Call the chat.postMessage method using the built-in WebClient
    const result = await app.client.chat.update({
      // The token you used to initialize your app is stored in the `context` object
      token: botTokenContext,
      // Payload message should be posted in the channel where original message was heard
      channel: spinChannelID,
      ts: spinTS,
      as_user: true,
      text: "A couple FCBuddies have started a Slackroulette session!",
      blocks: [
        {
          "type": "section",
          "text": {
            "type": "mrkdwn",
            "text": "A couple FCBuddies have started a Slackroulette session!"
          }
        },
        {
          "type": "section",
          "text": {
            "type": "mrkdwn",
            "text": "Spin the Slackroulette wheel to start another Slackroulette session."
          }
        },
        {
          "type": "actions",
          "elements": [
            {
              "type": "button",
              "text": {
                "type": "plain_text",
                "text": "Spin the Wheel"
              },
              "action_id": "spin_wheel"
            }
          ]
        }
      ]
    });

    console.log(result);
  }
  catch (error) {
    console.error(error);
  }
}

(async () => {
  // Start your app
  await app.start(process.env.PORT || 3000);

  console.log('⚡️ Bolt app is running!');
})();

