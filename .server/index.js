const express = require('express')
var bodyParser = require('body-parser')
const crypto = require('crypto');
const sharp = require('sharp');
const jwt = require('jsonwebtoken');
const safeCompare = require('safe-compare');
const fs = require('fs');
require('dotenv').config();

const app = express()
app.use(bodyParser.json({ limit: '2mb' }))       // to support JSON-encoded bodies
app.use(bodyParser.urlencoded({     // to support URL-encoded bodies
    extended: true
})); 


const privateKey = fs.readFileSync('private.key'); 
//const privateKey = crypto.randomBytes(32);

const port = process.env.port;

const { MongoClient } = require('mongodb');
const mongoDB_dataBase = process.env.mongoDB_dataBase;
const mongodb_url = process.env.mongodb_url;
const mongodb_client = new MongoClient(mongodb_url, {
  useNewUrlParser: true, 
  useUnifiedTopology: true, 
  serverSelectionTimeoutMS: 5000 
});
mongodb_client.connect()
const database = mongodb_client.db(mongoDB_dataBase);


function generateRandomString(length) {
  const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let result = '';
  for (let i = 0; i < length; i++) {
    const randomIndex = crypto.randomInt(0, chars.length);
    result += chars.charAt(randomIndex);
  }
  return result;
}


//create a key for putting in file, leaving where for when needed
//console.log(require('crypto').randomBytes(32).toString('hex'))

async function updateUserPassword(email, newPassword) {
  try {
    // Retrieve the user document using the email
    const collection = database.collection("user_credentials");

    const user = collection.findOne({ email:email })

    if (!user) {
      throw new Error('User not found');
    }

    // Generate a new hashed password
    const passwordSalt = crypto.randomBytes(16).toString('hex');
    const hashedPassword = crypto.createHash("sha256")
    .update(newPassword)
    .update(crypto.createHash("sha256").update(passwordSalt, "utf8").digest("hex"))
    .digest("hex");


    // Update the user document with the new hashed password
    await collection.updateOne(
      { _id: user._id },
      { $set: {
        hashedPassword: hashedPassword,
        passwordSalt: passwordSalt,
      }}
      );
  } catch (error) {
    console.log('Error updating password:', error);
  }
}

//updateUserPassword("jsowry936@gmail.com","1234")


async function createUser(email,password,username){
  try{
    const userCredentialsCollection = database.collection("user_credentials");
    const userDataCollection = database.collection("user_data");
    const passwordSalt = crypto.randomBytes(16).toString('hex');
    const hashedPassword = crypto.createHash("sha256")
    .update(password)
    .update(crypto.createHash("sha256").update(passwordSalt, "utf8").digest("hex"))
    .digest("hex");

    //make sure email is not in use
    var emailInUse = true;
    try{
      const result = await userCredentialsCollection.findOne({ email: email })
      if (result === null){
        emailInUse = false;
      }
    }catch(err){
      console.log(err);
    }

    if(emailInUse===true){
      return false;
    }

    //create userId and make sure no one has it
    var userId = "";
    var invaildUserId = true;
    while(invaildUserId){
      userId = generateRandomString(16);
      try{
        const result = await userCredentialsCollection.findOne({ userId: userId })
        if (result === null){
          invaildUserId = false;
        }
      }catch(err){
        console.log(err);
      }
    }
   
    var tokenNotExpiredCode = generateRandomString(16);

    const userCredentialsOutput = await userCredentialsCollection.insertOne(
      {
        userId: userId,
        email: email,
        hashedPassword: hashedPassword,
        passwordSalt: passwordSalt,
        accountBanned: false,
        accountBanReason: "",
        accountBanExpiryDate: 0,
        failedLoginAttemptInfo: {},
        tokenNotExpiredCode: tokenNotExpiredCode,
        loginHistory: {},
      }
    )
    const userDataOutput = await userDataCollection.insertOne(
      {
        userId: userId,
        username: username,
        bio: "",
        avatar: null,
        cooldowns: {},
        administrator: false,
      }
    )
    if (userCredentialsOutput.acknowledged === true && userDataOutput.acknowledged === true){
      return true;
    }

    return false
  }catch (err){
    console.log(err);
    return false;
  }
  //phone number

}

//createUser("jsowry936@gmail.com","1234");

async function testToken(token,ipAddress){
  try{
    var decoded = "";
    try{
      decoded = jwt.verify(token, privateKey);
    }catch (err){
      console.log(err);
      return [false];
    }
    if (decoded == null){
      return [false]
    };

    const userId = decoded.userId;


    //get data from server
    var collection = database.collection('user_credentials');
    const userData = await collection.findOne({ userId: userId });

    //make sure token is not invald bcause of password reset
    if(decoded.tokenNotExpiredCode !== userData.tokenNotExpiredCode){
      return [false]; 
    };

    //another test to make sure it is the same ip address
    if(decoded.ipAddress !== ipAddress){
      return [false];
    };

    //another test to make sure device header informastion is the same as before


    //make sure to test if the token time is out of date
    //look into soon think its auto done
    return [true, userId];
    

  }catch(err){
    console.log(err);
    return [false];
  }

}

// GET method route
app.get('/', (req, res) => {
  res.send("nothing");
})
  
// POST method route
app.post('/login', async (req, res) => {
  try{
    console.log("user login")
    //add rate limitng
    //add system to see if the same ip address is making alot of requests
    //add system to make sure account is not locked with all ip's, that ip or anything
    //add system to make sure account is not banned
    //MAKE SURE WHEN SETTING UP NGINX TO SEE THAT IT FORWARDS IP ADDRESSES
    //make sure they are not in global ip addresses banned
    //add to login history
    //add a system that locks out ip addresses for along time instead of just alittle bit.

    const userEmail = req.body.email;
    const userPassword = req.body.password;
    const userIpAddress = req.ip;

    //https://www.npmjs.com/package/jsonwebtoken
    //bind info like ip address and stuff to token as well
    //bind when it was made to token

    
    // get user info from database //
    const collection = database.collection('user_credentials');

    const userData = await collection.findOne({ email: userEmail });
    //make sure it is vaild account lol
    if (userData === null){
      res.status(401).send("invalid login credentials"); //incorrect login
      return;
    }
    const hashedPassword = userData.hashedPassword;
    const passwordSalt = userData.passwordSalt;
    const userId = userData.userId;
    
    //   tests to run   //
    //login cooldown
    //the way this works is abit werid so ima explain it.
    //when a login it failed a counter storeing recent failed logins will increase, depending on how high this value is a time will be set for when the account will be unlocked out, worth noting when that time expires this counter will not go back down.
    //another counter is stored, which is when these login attempts will expire, each new failed login attempt will incresse this value, 
    //however there is a second counter which stores how long until the counter will be reset, this is much longer and this counter may still be running while you can still login.
    if (userData.failedLoginAttemptInfo[userIpAddress] === undefined){
      //make the info setup
      userData.failedLoginAttemptInfo[userIpAddress] = {
        recentAttemptNumber : 0,
        resetCounterTime : 0,
        lockoutTime : 0,
      }
    }
    
    //if the counter is greater than the time until the counter is reset, then the account is locked
    if(userData.failedLoginAttemptInfo[userIpAddress].recentAttemptNumber > 0){
      //if lockout time is still within the range of login
      if(userData.failedLoginAttemptInfo[userIpAddress].lockoutTime > Date.now()){
        res.status(408).send("login timeout " + String(Math.ceil((userData.failedLoginAttemptInfo[userIpAddress].lockoutTime - Date.now()) / 1000)) + " seconds left")


        return;
      }else{
        //see counter is due to be reset
        if(userData.failedLoginAttemptInfo[userIpAddress].resetCounterTime > Date.now()){
          //reset all counters
          userData.failedLoginAttemptInfo[userIpAddress].recentAttemptNumber = 0;
          userData.failedLoginAttemptInfo[userIpAddress].resetCounterTime = 0;
          userData.failedLoginAttemptInfo[userIpAddress].lockoutTime = 0;
        }
      }
    }
      
    



    const hashedPasswordEntered = crypto.createHash("sha256")
    .update(userPassword)
    .update(crypto.createHash("sha256").update(passwordSalt, "utf8").digest("hex"))
    .digest("hex");

    //if the username and password is the same
    if(safeCompare(hashedPasswordEntered,hashedPassword)){
      
      //should add a system for when it fails to sign, then again probs not needed
      var token = jwt.sign({
        userId : userId,
        ipAddress : userIpAddress,
        //token not expired code, used to make sure that user has not done password reset or anything
        tokenNotExpiredCode: userData.tokenNotExpiredCode,
      }, privateKey, {expiresIn: '30d'});
      
      res.status(200).json({
        token: token,
        userId: userId,
      });
      return;

    }else{
      //will count up ip address lockout time
      const recentAttemptNumber = userData.failedLoginAttemptInfo[userIpAddress].recentAttemptNumber + 1;
      //don't like theses numbers quite yet.
      const lockoutTime = Date.now() + (Math.pow(1.250,recentAttemptNumber) * 5)  * 1000;
      const resetCounterTime = Date.now() + (Math.pow(1.250,recentAttemptNumber) * 15)  * 1000;

      //save to mongodb
      await collection.updateOne(
        { email: userEmail },
        { $set: {
          failedLoginAttemptInfo: {
            [userIpAddress]: {
              recentAttemptNumber : recentAttemptNumber,
              resetCounterTime: resetCounterTime,
              lockoutTime : lockoutTime,
              }
            }
          }
        }
      );
      res.status(401).send("invalid login credentials"); //incorrect login
      return;
    }

    //res.send('POST request to the homepage')
  }catch(err){
    res.status(401).send("invalid login credentials");
    console.log(err);
    return;
  }
})

app.post('/testToken', async (req, res) => {
  console.log("user testing token")
  const token = req.body.token;
  var tokenVaild, userId;
  [tokenVaild, userId] = await testToken(token,req.ip)

  if(tokenVaild){
    console.log("vaild token");
    res.status(200).send();
  }else{
    console.log("invaild token");
    res.status(401).send();
  }

})

app.post('/getProfile', async (req, res) => {
  console.log("user fetching profile")
  try{
    const token = req.body.token;
    [validToken, requesterUserId] = await testToken(token,req.ip)
    const collection = database.collection('user_data');

    if (validToken === false){
      res.status(401).send("invaild token");
    }


    //if they dont supply any user just fetch themselves
    var fetchingUserId = requesterUserId
    if (req.query.userId) {
      fetchingUserId = req.query.userId
    }

    const userData = await collection.findOne({ userId: userId })


    res.status(200).json({
      username: userData.username,
      bio: userData.bio,

    });
    
  }catch(err){
    console.log(err);
    res.status(500).send("server error")
  }
})

//createUser("jsowry936@gmail.com","1234","toasterLover46")

app.post('/post/upload', async (req, res) => {
  console.log("user uploading post")
  try{
    const token = req.body.token;
    const title = req.body.title;
    const description = req.body.description;
    const base64Image = req.body.image;
    const shareMode = req.body.shareMode;
    var postId;
    
    var vaildToken = false;
    var userId = "";
    [vaildToken, userId] = await testToken(token,req.ip); //frankly I have no idea why you need the square brackets but it fixes it so eh

    if (vaildToken) {
      var collection = database.collection('posts');

      const image = req.file;
      var imageId = generateRandomString(16);
      while (fs.existsSync(imageId)) {
        imageId = generateRandomString(16);
      }

      //loop over making sure post Id is not used
      while (true){
        postId =  generateRandomString(16);

        let postIdInUse = await collection.findOne({postId: postId});
        if (postIdInUse === null){
          break
        }
      }


      //make sure title not to large or empty and isn't null or undefined
      if (title.length > 50) {
        return res.status(400).send('title is to large.');
      }else if (title === null || title.match(/^ *$/) !== null || title === undefined) {
        return res.status(400).send('title is empty.');
      }

      //make sure description not to large or empty and isn't null or undefined
      if (description.length > 250) {
        return res.status(400).send('description is to large');
      }else if (description === null || description.match(/^ *$/) !== null || description === undefined) {
        return res.status(400).send('description is empty.');
      }

      //make sure user has perms to view it
      if (shareMode === "public") {
      }else if (shareMode === "friends"){
      }else{
        return res.status(400).send('Invaild share mode.');
      }

      //upload image
      try{
        imageData = Buffer.from(base64Image, 'base64');

        //make sure image is right size
        const imageMetadata = await sharp(imageData).metadata();
        const { width, height } = imageMetadata;
        const MAX_RESOLUTION = {
          width: 1080,
          height: 1080,
        };
        if ((width === MAX_RESOLUTION.width && height === MAX_RESOLUTION.height) === false) {
          return res.status(400).send('Image resolution exceeds the allowed limit.');
        }
      
        fs.writeFileSync(`./images/${imageId}.jpg`, imageData);


      } catch (err) {
        console.log(err)
        return res.status(400).send('error saving image');
      }

      response = await collection.insertOne(
        {
          posterUserId: userId,
          title: title,
          description: description,
          image: imageId,
          postDate: Date.now(),
          shareMode: shareMode,
          postId: postId,
          reviews: {

          },
          rating:0.0,
        }
      )

      

      return res.status(200).send('created post');

    }else{
      res.status(401).send("invaild token");
    }
  
  }catch(err){
    console.log(err);
  }

})

app.post('/post/data', async (req, res) => {
  try{
    console.log("user fetching post")
    const token = req.body.token;
    var vaildToken, userId;

    [vaildToken, userId] = await testToken(token,req.ip)
    const postId = req.body.postId;
  
    if (vaildToken) { // user token is valid
      var collection = database.collection('posts');
      var userDataCollection = database.collection('user_data');
      var itemData = await collection.findOne({postId: postId})

      if (itemData === null) {
        return res.status(404).send("invaild post");
      }

      if (itemData.shareMode !== 'public'){
        return res.status(403).send("can't view post");
      }
      

      let imageData = null;
      imageData = fs.readFileSync(`./images/${itemData.image}.jpg`)
      imageData = imageData.toString('base64');


      const posterUserData = await userDataCollection.findOne({ userId: itemData.posterUserId })
      if (posterUserData === undefined || posterUserData === null) {
        return res.status(400).send("unkown poster");
      }

      return res.status(200).json({
        title : itemData.title,
        description : itemData.description,
        rating : itemData.rating,
        postId : postId,
        imageData : imageData,
        posterData : {
          username : posterUserData.username,
        },
      });

    }else{
      return res.status(401).send("invaild token");
    }
  }catch(err){
    console.log(err);
  }
})

app.post('/post/feed', async (req, res) => {
  try{
    const token = req.body.token;
    const startPosPost = req.body.startPosPost;
    var startPosPostDate = 100000000000000
    var vaildToken, userId;

    [vaildToken, userId] = await testToken(token,req.ip)
    const postId = req.body.postId;
  
    if (vaildToken) { // user token is valid
      var collection = database.collection('posts');
      var posts;

      if (startPosPost) {
        const startPosPostData = await collection.findOne({ postId: startPosPost })
        if (!startPosPostData){
          return res.status(400).send("invaild start post");
        }else{
          startPosPostDate = startPosPostData.postDate;
        }
      }

      posts = await collection.find({ shareMode: 'public', postDate: { $lt: startPosPostDate}}).sort({postDate: -1}).limit(2).toArray();
      var returnData = {}
      returnData["posts"] = []
      

      for (var i = 0; i < posts.length; i++) {
        returnData["posts"].push(posts[i].postId);
        //Do something
      }

      return res.status(200).json(returnData);

    }else{
      return res.status(401).send("invaild token");
    }
  }catch(err){
    console.log(err);
  }
})

app.listen(port, () => {
  console.log(`Toaster server listening on port ${port}`)
})



//features to add
//reset password
//profile's
// //show past posts
// // //delete old posts
// //reset password
// //change username
// //change email
// //logout current or all devices
// //private accounts
// //delete all data
//report feature
//adding as friend
//rating posts
//ban prompt 
// //creating posts
//indexing posts to be faster
//lisences
// //use AboutDialog to get lisences from packages
//privacy polocy

//security to add
//root detection etc, bans after login
//certificate pinning
//bans based on device fingerprint
//captcha for alota logins
//block proxy's and vpns
//device fingerprint to token
//login history
//rate limiting
// //pots
// //searching for things
// //ading frineds

//bugs to fix
//look at why I always need to relogin
//lack of post caching, scrolling spam regets from servers
//add error checking for post item being added to documents in mongodb
//loading screen after take photo and upload photo
//delete old photos not needed when taking picture
//fix up login timeouts formula
//dark mode popups
//postion of take picture

//possible future features
//chat system
//search menu
//nicer failed getting posts
//extra camera settings
// //add setting for not using flashlight
// //zoom for camera
//way to suggest features
//toaster leaderboards
//toaster streaks
//improve server error reporting
//sign in with google
//shareing toasts
// //toaster watermark
//reached end of your feed
//how long ago post was uploaded
//able to click on user profile avatar and name to open them on posts
//block users

//low resolstion
//overflow on public or private post part
//overflow on login screen

//plugins to use
//use image_cropper for user avatars
