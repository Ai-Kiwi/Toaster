import 'dart:convert';

import 'package:Toaster/postRating/userRating.dart';
import 'package:Toaster/posts/userPost.dart';
import 'package:flutter/material.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import '../login/userLogin.dart';

class LazyLoadPage extends StatefulWidget {
  final Widget widgetAddedToTop;
  final Widget widgetAddedToEnd;
  final Widget widgetAddedToBlank;
  final String urlToFetch;
  final extraUrlData;

  const LazyLoadPage({
    super.key,
    required this.widgetAddedToTop,
    required this.urlToFetch,
    required this.widgetAddedToEnd,
    required this.widgetAddedToBlank,
    this.extraUrlData,
  });

  @override
  State<LazyLoadPage> createState() => _LazyLoadPageState(
        widgetAddedToTop: widgetAddedToTop,
        urlToFetch: urlToFetch,
        extraUrlData: extraUrlData,
        widgetAddedToEnd: widgetAddedToEnd,
        widgetAddedToBlank: widgetAddedToBlank,
      );
}

class _LazyLoadPageState extends State<LazyLoadPage> {
  Widget widgetAddedToTop;
  Widget widgetAddedToEnd;
  Widget widgetAddedToBlank;
  ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  final double scrollDistence = 0.8;
  final String urlToFetch;
  var extraUrlData;

  _LazyLoadPageState({
    required this.widgetAddedToTop,
    required this.urlToFetch,
    required this.widgetAddedToEnd,
    required this.widgetAddedToBlank,
    this.extraUrlData,
  });

  var lastItem;
  var itemsCollected = [];

  Future<void> _fetchItems() async {
    //test if they have reached the end
    if (itemsCollected.length > 0) {
      if (itemsCollected[itemsCollected.length - 1] == "end" ||
          itemsCollected[itemsCollected.length - 1] == "blank") {
        return;
      }
    }
    _isLoading = true; //say that it is loading more
    //setup data for sending
    Map<dynamic, dynamic> dataSending = {
      'token': userManager.token,
    };
    //add all the extra parm's
    if (extraUrlData != null) {
      dataSending.addAll(extraUrlData!);
    }

    if (lastItem != null) {
      dataSending['startPosPost'] = lastItem!;
    }
    final response = await http.post(
      Uri.parse("$serverDomain$urlToFetch"),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(dataSending),
    );
    if (response.statusCode == 200) {
      setState(() {
        var fetchedData = jsonDecode(response.body);
        var postData = fetchedData["items"];
        if (fetchedData["items"].isEmpty) {
          if (itemsCollected.isEmpty) {
            itemsCollected.add("blank");
          } else {
            itemsCollected.add("end");
          }
          return;
        }
        for (var post in postData) {
          itemsCollected.add(post);
          lastItem = post;
        }
      });
    } else {
      setState(() {
        Alert(
          context: context,
          type: AlertType.error,
          title: "an error occurred while getting new items",
          desc: response.body,
          buttons: [
            DialogButton(
              onPressed: () => Navigator.pop(context),
              width: 120,
              child: const Text(
                "ok",
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            )
          ],
        ).show();
      });
    }
    _isLoading = false;
  }

  void _onScroll() {
    if (_isLoading == false &&
        _scrollController.position.pixels >=
            (_scrollController.position.maxScrollExtent * scrollDistence)) {
      _fetchItems();
    }
  }

  void updateChildWidget(String newState) {
    setState(() {
      widgetAddedToTop = widgetAddedToTop;
      widgetAddedToEnd = widgetAddedToEnd;
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchItems();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    //final ThemeData theme = Theme.of(context);
    return Container(
      decoration: const BoxDecoration(color: Color.fromRGBO(16, 16, 16, 1)),
      child: Center(
        child: ListView.builder(
          controller: _scrollController,
          itemCount: itemsCollected.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return widgetAddedToTop;
            } else if (itemsCollected[index - 1] == "end") {
              return widgetAddedToEnd;
            } else if (itemsCollected[index - 1] == "blank") {
              return widgetAddedToBlank;
            } else {
              if (itemsCollected[index - 1]["type"] == "post") {
                return PostItem(
                  postId: itemsCollected[index - 1]["data"],
                );
              } else if (itemsCollected[index - 1]["type"] == "rating") {
                return userRating(
                  ratingId: itemsCollected[index - 1]["data"],
                );
              }
            }
            return null;
          },
        ),
      ),
    );
  }
}
