import 'dart:convert';
import 'dart:io';

import 'package:PlateRates/chat/chatList.dart';
import 'package:PlateRates/firebase_options.dart';
import 'package:PlateRates/libs/loadScreen.dart';
import 'package:PlateRates/notifications/appNotificationHandler.dart';
import 'package:PlateRates/notifications/notificationPageList.dart';
import 'package:PlateRates/userProfile/userProfile.dart';
import 'package:PlateRates/userFeed/userFeed.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_flavor/flutter_flavor.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:json_cache/json_cache.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'createPost/createPostPhoto.dart';
import 'libs/pageNotices.dart';
import 'login/userLogin.dart';
import 'navbar.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

String serverDomain = 'https://platerates.com';
String serverWebsocketDomain = 'wss://platerates.com';

void main() {
  //make sure something a rather to use app verison

  WidgetsFlutterBinding.ensureInitialized();

  //if (kDebugMode == true) {}

  if (FlavorConfig.instance.variables["release"] == "test") {
    serverDomain = 'http://192.168.0.157:3030';
    serverWebsocketDomain = 'ws://192.168.0.157:3030';
  } else if (FlavorConfig.instance.variables["release"] == "dev") {
    serverDomain = 'https://platerates.com';
    serverWebsocketDomain = 'wss://platerates.com';
  }

  runApp(Phoenix(child: const MyApp()));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
}

late JsonCacheMem jsonCache;
//make sure it is running the latest verison
late String appName;
late String packageName;
late String version;
late String buildNumber;
bool acceptedAllLicenses = true;
bool accountBanned = false;
var primaryColor = Colors.green;
const primaryColorCodes = {
  "red": Colors.red,
  "deepOrange": Colors.deepOrange,
  "orange": Colors.orange,
  "yellow": Colors.yellow,
  "lime": Colors.lime,
  "lightGreen": Colors.lightGreen,
  "green": Colors.green,
  "teal": Colors.teal,
  "cyan": Colors.cyan,
  "lightBlue": Colors.lightBlue,
  "blue": Colors.blue,
  "indigo": Colors.indigo,
  "deepPurple": Colors.deepPurple,
  "purple": Colors.purple,
  "pink": Colors.pink,
  "brown": Colors.brown,
};
var backgroundColor = const Color.fromRGBO(16, 16, 16, 1);
final numberFormatter =
    NumberFormat.compact(locale: "en_US", explicitSign: false);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Stream<String> initializeApp(context) async* {
    //open encrypted storage for some other data stored
    var sharedPrefs = await SharedPreferences.getInstance();

    String? colorThemePrimaryColor = sharedPrefs.getString('primaryColor');

    print("setting main color");
    if (colorThemePrimaryColor != null) {
      if (primaryColorCodes[colorThemePrimaryColor] != null) {
        if (primaryColor == Colors.green &&
            primaryColorCodes[colorThemePrimaryColor] != Colors.green) {
          //reloads if color changes that way you see it
          primaryColor = primaryColorCodes[colorThemePrimaryColor]!;
          print("set color to $colorThemePrimaryColor and reload");
          Phoenix.rebirth(context);
          return;
        } else {
          primaryColor = primaryColorCodes[colorThemePrimaryColor]!;
          print("set color to $colorThemePrimaryColor no reload needed");
        }
      } else {
        print("invalid value leaving default");
      }
    } else {
      print("no value leaving default");
    }

    //setup verison stuff
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    appName = packageInfo.appName;
    packageName = packageInfo.packageName;
    version = packageInfo.version;
    buildNumber = packageInfo.buildNumber;

    print("setting up cache");
    //load in json cache stuff
    await Hive.initFlutter();

    if (kIsWeb == true) {
      final box =
          await Hive.openBox<String>('appBox'); // it must be a Box<String>.
      jsonCache = JsonCacheMem(JsonCacheHive(box));
    } else {
      final tempDir = await getTemporaryDirectory();
      final box = await Hive.openBox<String>('appBox',
          path:
              "${tempDir.path}/cacheData.tastyCache"); // it must be a Box<String>.
      jsonCache = JsonCacheMem(JsonCacheHive(box));
    }

    //if I change reset data this also needs to be changed in login script as well as logout script in alerts
    var expireTime = await jsonCache.value("expire-data");
    if (expireTime == null) {
      print("cache expire time is null");
      await jsonCache.clear();
      await jsonCache.refresh("expire-data", {
        "expireTime": DateTime.now().day,
        "clientVersion": '$version+$buildNumber'
      });
    } else {
      if (expireTime["expireTime"] < (DateTime.now().day - 7)) {
        print("cache expire time has expired");
        await jsonCache.clear();
        await jsonCache.refresh("expire-data", {
          "expireTime": DateTime.now().day,
          "clientVersion": '$version+$buildNumber'
        });
      } else {
        if (expireTime["clientVersion"] != '$version+$buildNumber') {
          print("cache version is old");
          await jsonCache.clear();
          await jsonCache.refresh("expire-data", {
            "expireTime": DateTime.now().day,
            "clientVersion": '$version+$buildNumber'
          });
        } else {
          print("cache expire time is still active");
        }
      }
    }

    print("starting flutter downloader");
    if (FlutterDownloader.initialized == false) {
      await FlutterDownloader.initialize(
          debug:
              true, // optional: set to false to disable printing logs to console (default: true)
          ignoreSsl:
              true // option: set to false to disable working with http links (default: false)
          );
    }

    print("starting firebase");
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    if (kDebugMode == true) {
      FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
    }

    print("asking server for the latest verison");
    //contact server and get verison
    try {
      print("$serverDomain/latestVersion");
      final response = await http.get(
        Uri.parse("$serverDomain/latestVersion"),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );
      if (response.statusCode == 200) {
        if (response.body != '$version+$buildNumber') {
          print('server : ${response.body}');
          print('client : $version+$buildNumber');
          yield "client-out-of-date";
          return;
        }
      } else {
        yield "server-contact-error";
        return;
      }
    } catch (err) {
      yield "server-contact-error";
      return;
    }

    print("loading in token");
    //load in token
    if (userManager.token == "") {
      await userManager.loadTokenFromStoreage();
    }

    print("starting app check");
    if (kDebugMode == false) {
      await FirebaseAppCheck.instance.activate(
        //webRecaptchaSiteKey: 'recaptcha-v3-site-key',
        androidProvider: AndroidProvider.playIntegrity,
        // Default provider for iOS/macOS is the Device Check provider. You can use the "AppleProvider" enum to choose
        // your preferred provider. Choose from:
        // 1. Debug provider
        // 2. Device Check provider
        // 3. App Attest provider
        // 4. App Attest provider with fallback to Device Check provider (App Attest provider is only available on iOS 14.0+, macOS 14.0+)
        // appleProvider: AppleProvider.appAttest,
      );
    } else {
      await FirebaseAppCheck.instance.activate(
        //webRecaptchaSiteKey: 'recaptcha-v3-site-key',
        androidProvider: AndroidProvider.debug,
        // Default provider for iOS/macOS is the Device Check provider. You can use the "AppleProvider" enum to choose
        // your preferred provider. Choose from:
        // 1. Debug provider
        // 2. Device Check provider
        // 3. App Attest provider
        // 4. App Attest provider with fallback to Device Check provider (App Attest provider is only available on iOS 14.0+, macOS 14.0+)
        // appleProvider: AppleProvider.appAttest,
      );
    }
    if (kIsWeb == false) {
      print("starting notifcation service");
      await initNotificationHandler(); //also handles firebase

      //load notfcation stuff if opened

      //var notData = sharedPrefs.getString('notificationOnBootData');
      //print("noti thingy is $notData");
      //if (notData != null) {
      //  if (notData != '') {
      //    openNotificationOnBootData = notData;
      //    print("loaded ");
      //    sharedPrefs.setString('notificationOnBootData', '');
      //  }
      //}
    }

    //test licenses
    print("testing if license is the all accepted");
    var response = await http.get(
      Uri.parse("$serverDomain/licenses/unaccepted"),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        HttpHeaders.authorizationHeader: userManager.token
      },
    );
    print(response.body);
    print(response.statusCode);
    if (response.statusCode == 200) {
      Map<String, dynamic> jsonResponse = await jsonDecode(response.body);

      if (jsonResponse.isNotEmpty) {
        yield "invalid-licenses";
        return;
      }
    }

    //respond with if token is valid
    yield "success";
    return;
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return FlavorBanner(
        child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: primaryColor,
              statusBarIconBrightness: Brightness.light,
              systemNavigationBarIconBrightness: Brightness.dark,
            ),
            child: MaterialApp(
                title: 'Platerates',
                theme: ThemeData(
                  useMaterial3: false,
                  indicatorColor: primaryColor,
                  primaryColor: primaryColor,
                  primarySwatch: primaryColor,

                  //Theme.of(context).primarySwatch
                  dialogBackgroundColor: Color.fromRGBO(16, 16, 16, 1),
                  scaffoldBackgroundColor: Color.fromRGBO(16, 16, 16, 1),
                ),
                home: StreamBuilder<String>(
                  stream: initializeApp(context),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      // Show a loading indicator while the authentication state is being fetched
                      return LoadingScreen(
                        plateRatesLogo: true,
                      );
                    } else {
                      print(snapshot.data);
                      //if (snapshot.hasData && snapshot.data == true) {
                      if (snapshot.data == "success") {
                        // navigate to home page finished everything
                        return MyHomePage();
                      } else if (snapshot.data == "server-contact-error") {
                        //error contacting server
                        return DisplayErrorMessagePage(
                            errorMessage: "error contacting server");
                      } else if (snapshot.data == "client-out-of-date") {
                        //  //client is out of date
                        return DisplayErrorMessagePage(
                            errorMessage: "client-out-of-date");
                      } else if (snapshot.data == "invalid-licenses") {
                        return const PromptUserToAcceptNewLicenses();
                      } else {
                        // User is not logged in, navigate to login page
                        return DisplayErrorMessagePage(
                            errorMessage:
                                "unkown problem with starting platerates");
                      }
                    }
                  },
                ))));
  }
}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

List<Widget> pages = <Widget>[
  userFeed(),
  CameraPage(),
  notificationPageList(),
  LoggedInUserTab(),
];

Future<void> testNotificationOnBootData(context) async {
  if (openNotificationOnBootData != "") {
    openNotification(openNotificationOnBootData, context);

    openNotificationOnBootData = "";
    var sharedPrefs = await SharedPreferences.getInstance();
    sharedPrefs.setString('notificationOnBootData', '');
  }
}

var updateUnreadNotificationCount;
var updateHomePage;

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  double containerWidth = 200.0;
  double containerHeight = 300.0;

  void _onItemSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    updateUnreadNotificationCount = _updateUnreadNotificationCount;
    updateUnreadNotificationCount();
    updateHomePage = _updateHomePage;
  }

  int unreadNotificationCount = 0;
  int unreadMessagesCount = 0;

  Future<void> _updateUnreadNotificationCount() async {
    try {
      var response = await http.post(
        Uri.parse("$serverDomain/notification/unreadCount"),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          HttpHeaders.authorizationHeader: userManager.token,
        },
        body: jsonEncode(<String, String>{}),
      );

      if (response.statusCode == 200) {
        print(response.body);
        var jsonData = jsonDecode(response.body);

        if (mounted) {
          setState(() {
            unreadNotificationCount = jsonData['unreadCount'];
            unreadMessagesCount = jsonData['newChatMessages'];
            //unreadMessageCount = jsonData['unreadMessageCount'];
          });
        }
      }
    } on Exception catch (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(error, stackTrace);
    }
  }

  Future<void> _updateHomePage() async {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb == true) {
      // Get the screen dimensions
      double screenWidth = MediaQuery.of(context).size.width;
      double screenHeight = MediaQuery.of(context).size.height;

      // Calculate the aspect ratio
      double aspectRatio = screenHeight / screenWidth;

      if (aspectRatio < 1.5) {
        return DisplayErrorMessagePage(errorMessage: "screen to wide");
      }
    }

    //see if notifcation has been clicked and if so display it
    //testNotificationOnBootData(context);

    if (acceptedAllLicenses == false) {
      return PromptUserToAcceptNewLicenses();
    } else if (accountBanned == true) {
      return PromptUserBanned();
    }

    return Scaffold(
        extendBody: true,
        body: Center(
          child: pages.elementAt(_selectedIndex),
        ),
        bottomNavigationBar: UserNavbar(
          notificationCount: unreadNotificationCount,
          unreadMessagesCount: unreadMessagesCount,
          selectedIndex: _selectedIndex,
          onClicked: _onItemSelected,
        ));
  }
}

//export PATH="$PATH":"$HOME/.pub-cache/bin"
//flutterfire
