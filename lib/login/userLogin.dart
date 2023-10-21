import 'dart:convert';

import 'package:Toaster/libs/alertSystem.dart';
import 'package:Toaster/login/createAccount.dart';
import 'package:Toaster/login/userResetPassword.dart';
import 'package:Toaster/notifications/appNotificationHandler.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../libs/smoothTransitions.dart';
import '../main.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const storage = FlutterSecureStorage();

class LoginResponse {
  bool? success;
  String? error;

  LoginResponse({this.success, this.error});
}

// User class
class User {
  String token = "";

  //User({this.token});
  User();

  Future<void> loadTokenFromStoreage() async {
    String? tokenValue = await storage.read(key: "token");
    if (tokenValue == null) {
      token = "";
    } else {
      token = tokenValue.toString();
    }
  }

  Future<bool> checkLoginState() async {
    if (token == "") {
      return false;
    }
    try {
      final response = await http.post(
        Uri.parse("$serverDomain/testToken"),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'token': token,
        }),
      );
      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } on Exception catch (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(error, stackTrace);
      return false;
    }
  }

  Future<LoginResponse> loginUser(String emailAddress, String password) async {
    try {
      final response = await http.post(
        Uri.parse("$serverDomain/login"),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'email': emailAddress,
          'password': password,
        }),
      );
      if (response.statusCode == 200) {
        var returnData = jsonDecode(response.body);
        token = returnData["token"];
        await storage.write(key: "token", value: token);
        return LoginResponse(error: null, success: true);
      } else {
        return LoginResponse(error: response.body, success: false);
      }
    } catch (err) {
      return LoginResponse(error: "error contacting server", success: false);
    }
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String _username = '';
  String _password = '';

  @override
  Widget build(BuildContext context) {
    final _formKey = GlobalKey<FormState>();

    return Scaffold(
      backgroundColor: const Color.fromRGBO(16, 16, 16, 1),
      body: SafeArea(
          bottom: true,
          top: true,
          child: Center(
              //make sure on pc it's not to wide
              child: SizedBox(
                  width: 500,
                  height: double.infinity,
                  child: Form(
                      key: _formKey,
                      child: Column(
                        children: <Widget>[
                          const SizedBox(height: 48.0),
                          const Text(
                            "Login",
                            style: TextStyle(color: Colors.white, fontSize: 60),
                          ),
                          const SizedBox(height: 48.0),
                          Padding(
                            //email input feild
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: TextFormField(
                              onChanged: (value) {
                                _username = value;
                              },
                              autofillHints: const [AutofillHints.email],
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 20),
                              decoration: const InputDecoration(
                                labelText: 'Email Address',
                                labelStyle: TextStyle(
                                    color: Color.fromARGB(255, 200, 200, 200)),
                                contentPadding: EdgeInsets.all(8.0),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.green),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16.0),
                          Padding(
                            //password input feild
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: TextFormField(
                              onChanged: (value) {
                                _password = value;
                              },
                              autofillHints: const [AutofillHints.password],
                              obscureText: true,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 20),
                              decoration: const InputDecoration(
                                labelText: 'Password',
                                labelStyle: TextStyle(
                                    color: Color.fromARGB(255, 200, 200, 200)),
                                contentPadding: EdgeInsets.all(8.0),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.green),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              //login button
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16.0),
                              child: TextButton(
                                // reset password

                                onPressed: () {
                                  Navigator.of(context).push(smoothTransitions
                                      .slideUp(const ResetPasswordPage()));
                                },
                                child: const Text(
                                  'Forgot Password?',
                                  textAlign: TextAlign.start,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 8.0),
                          Padding(
                            //login button
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: SizedBox(
                              width: double.infinity,
                              height: 50.0,
                              child: ElevatedButton(
                                style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15.0),
                                )),
                                onPressed: () async {
                                  LoginResponse correctLogin = await userManager
                                      .loginUser(_username, _password);

                                  if (correctLogin.success == true) {
                                    //clear cache
                                    await jsonCache.clear();
                                    await jsonCache.refresh("expire-data", {
                                      "expireTime": DateTime.now().day,
                                      "clientVersion": '$version+$buildNumber'
                                    });
                                    //save login
                                    TextInput.finishAutofillContext();
                                    // ignore: use_build_context_synchronously
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => MyHomePage()),
                                    );
                                    //save
                                    // ignore: use_build_context_synchronously
                                    //informServerNotificationToken();
                                  } else {
                                    // ignore: use_build_context_synchronously
                                    openAlert("error", "invalid login",
                                        correctLogin.error, context, null);
                                  }
                                },
                                child: const Text(
                                  'Log in',
                                  style: TextStyle(fontSize: 18.0),
                                ),
                              ),
                            ),
                          ),
                          TextButton(
                            // reset password
                            onPressed: () {
                              Navigator.of(context).push(smoothTransitions
                                  .slideUp(const createAccountPage()));
                            },
                            child: RichText(
                              text: const TextSpan(
                                text: 'Don\'t have an account yet? ',
                                style: TextStyle(color: Colors.white),
                                children: <TextSpan>[
                                  TextSpan(
                                    text: 'Sign up here',
                                    style: TextStyle(
                                      fontWeight: FontWeight.normal,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          //Padding(
                          //  //login button
                          //  padding: const EdgeInsets.symmetric(
                          //      horizontal: 16.0, vertical: 16),
                          //  child: Row(
                          //    children: [
                          //      Expanded(
                          //        child: ElevatedButton(
                          //          style: OutlinedButton.styleFrom(
                          //              shape: RoundedRectangleBorder(
                          //            borderRadius: BorderRadius.circular(15.0),
                          //          )),
                          //          onPressed: () async {
                          //            GoogleSignIn _googleSignIn = GoogleSignIn(
                          //              scopes: [
                          //                'email',
                          //                //'https://www.googleapis.com/auth/contacts.readonly',
                          //              ],
                          //            );
                          //
                          //            //await _googleSignIn.signIn();
                          //            try {
                          //              final GoogleSignInAccount? googleUser =
                          //                  await _googleSignIn.signIn();
                          //              final GoogleSignInAuthentication?
                          //                  googleAuth =
                          //                  await googleUser?.authentication;
                          //              final String idToken =
                          //                  googleAuth!.idToken!;
                          //
                          //              print(idToken);
                          //              print("down sign in");
                          //            } on PlatformException catch (error) {
                          //              print("error with login $error");
                          //              // ignore: use_build_context_synchronously
                          //              openAlert(
                          //                  "error",
                          //                  "failed login with google",
                          //                  "$error",
                          //                  context,
                          //                  null);
                          //            }
                          //
                          //            //final bool isAuthorized =
                          //            //    await _googleSignIn
                          //            //        .requestScopes(['email']);
                          //            //if (isAuthorized) {
                          //            //  // Do things that only authorized users can do!
                          //            //}
                          //
                          //            await _googleSignIn.disconnect();
                          //          },
                          //          child: const Text(
                          //            'Log in with google',
                          //            style: TextStyle(fontSize: 18.0),
                          //          ),
                          //        ),
                          //      ),
                          //    ],
                          //  ),
                          //),
                        ],
                      ))))),
    );
  }
}

User userManager = User();
