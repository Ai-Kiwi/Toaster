import 'dart:convert';

import 'package:Toaster/libs/alertSystem.dart';
import 'package:Toaster/libs/lazyLoadPage.dart';
import 'package:Toaster/posts/userPost.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:http/http.dart' as http;
import '../libs/errorHandler.dart';
import '../main.dart';
import '../login/userLogin.dart';

class fullPagePost extends StatefulWidget {
  final String postId;

  const fullPagePost({super.key, required this.postId});

  @override
  _PostRatingListState createState() => _PostRatingListState(rootItem: postId);
}

class _PostRatingListState extends State<fullPagePost> {
  String uploadingRatingText = "";
  double uploadingRating = 5;
  String rootItem;
  bool hasRated = true;

  Future<void> _testRated() async {
    //attempt to upload post to see if you have posted yet
    final response = await http.post(
      Uri.parse("$serverDomain/post/rating/upload"),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode({
        "token": userManager.token,
        "rootItem": {"type": "post", "data": rootItem},
        "text":
            "this shouldn't have uploaded, massive server error right here.",
        "shareMode": "public",
      }),
    );

    setState(() {
      if (response.body == "you have already rated" ||
          response.body == "you can not rate your own post") {
        print(response.body);
        hasRated = true;
      } else {
        ErrorHandler.httpError(response.statusCode, response.body, context);
        hasRated = false;
      }
    });
  }

  _PostRatingListState({required this.rootItem});

  @override
  void initState() {
    super.initState();
    _testRated();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Stack(alignment: Alignment.topLeft, children: <Widget>[
      SafeArea(
          top: false,
          child: SizedBox(
              height: double.infinity,
              width: double.infinity,
              child: Column(
                children: [
                  Expanded(
                    child: LazyLoadPage(
                      widgetAddedToTop: Center(
                          child: Column(children: [
                        SizedBox(height: 32),
                        //const Padding(
                        //    padding: EdgeInsets.symmetric(
                        //        vertical: 16.0, horizontal: 16),
                        //    child: Text(
                        //      "post ratings",
                        //      style:
                        //          TextStyle(color: Colors.white, fontSize: 40),
                        //    )),
                        //const Divider(
                        //  color: Color.fromARGB(255, 110, 110, 110),
                        //  thickness: 1.0,
                        //),
                        PostItem(
                          postId: rootItem,
                          clickable: false,
                        )
                      ])),
                      widgetAddedToEnd: const Center(
                        child: Padding(
                            padding: EdgeInsets.symmetric(
                                vertical: 16.0, horizontal: 16),
                            child: Text(
                              "end of ratings.",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 25),
                            )),
                      ),
                      widgetAddedToBlank: const Center(
                        child: Padding(
                            padding: EdgeInsets.symmetric(
                                vertical: 16.0, horizontal: 16),
                            child: Text(
                              "no ratings to display",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 25),
                            )),
                      ),
                      extraUrlData: {
                        "rootItem": {"type": "post", "data": rootItem}
                      },
                      urlToFetch: '/post/ratings',
                    ),
                  ),
                  Visibility(
                      //menu for you to rate the post
                      visible: !hasRated,
                      child: Container(
                          decoration: const BoxDecoration(
                              borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(30.0),
                            topRight: Radius.circular(30.0),
                          )),
                          height: 233,
                          width: double.infinity,
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(children: [
                              RatingBar.builder(
                                initialRating: 5,
                                direction: Axis.horizontal,
                                allowHalfRating: true,
                                itemCount: 5,
                                itemPadding:
                                    const EdgeInsets.symmetric(horizontal: 4.0),
                                itemBuilder: (context, _) => const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                ),
                                onRatingUpdate: (rating) {
                                  uploadingRating = rating;
                                },
                              ),
                              SizedBox(height: 8),
                              TextField(
                                  keyboardType: TextInputType.multiline,
                                  maxLength: 500,
                                  maxLengthEnforcement: MaxLengthEnforcement
                                      .truncateAfterCompositionEnds,
                                  maxLines: 5,
                                  onChanged: (value) {
                                    uploadingRatingText = value;
                                  },
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 15),
                                  decoration: InputDecoration(
                                    counterText: "",
                                    labelText: 'rating text',
                                    labelStyle: const TextStyle(
                                      color: Color.fromARGB(255, 200, 200, 200),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15.0),
                                      borderSide: const BorderSide(
                                          width: 2,
                                          color:
                                              Color.fromARGB(255, 45, 45, 45)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15.0),
                                      borderSide: const BorderSide(
                                          width: 2,
                                          color:
                                              Color.fromARGB(255, 45, 45, 45)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15.0),
                                      borderSide: BorderSide(
                                          width: 2,
                                          color:
                                              Theme.of(context).primaryColor),
                                    ),
                                    contentPadding: const EdgeInsets.all(12.0),
                                    fillColor:
                                        const Color.fromARGB(255, 40, 40, 40),
                                    filled: true,
                                  )),
                              SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                height: 50.0,
                                child: ElevatedButton(
                                  style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15.0),
                                  )),
                                  onPressed: () async {
                                    //post rating
                                    final response = await http.post(
                                      Uri.parse(
                                          "$serverDomain/post/rating/upload"),
                                      headers: <String, String>{
                                        'Content-Type':
                                            'application/json; charset=UTF-8',
                                      },
                                      body: jsonEncode({
                                        "token": userManager.token,
                                        "text": uploadingRatingText,
                                        "shareMode": "public",
                                        "rating": uploadingRating,
                                        "rootItem": {
                                          "type": "post",
                                          "data": rootItem
                                        },
                                      }),
                                    );

                                    if (response.statusCode == 201) {
                                      // ignore: use_build_context_synchronously
                                      openAlert("success", "uploaded rating",
                                          null, context, null);
                                      await jsonCache.remove('post-$rootItem');
                                      // ignore: use_build_context_synchronously
                                      Navigator.pop(context);
                                      // ignore: use_build_context_synchronously
                                      Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  fullPagePost(
                                                      postId: rootItem)));
                                    } else {
                                      // ignore: use_build_context_synchronously
                                      ErrorHandler.httpError(
                                          response.statusCode,
                                          response.body,
                                          context);
                                      // ignore: use_build_context_synchronously
                                      openAlert(
                                          "error",
                                          "failed uploading rating",
                                          response.body,
                                          context,
                                          null);
                                    }
                                  },
                                  child: const Text(
                                    'publish rating',
                                    style: TextStyle(fontSize: 18.0),
                                  ),
                                ),
                              )
                            ]),
                          ))),
                ],
              ))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        child: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 30,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      )
    ]));
  }
}
