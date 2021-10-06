import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:android_path_provider/android_path_provider.dart';
import 'package:device_apps/device_apps.dart';
import 'package:device_info/device_info.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:r_upgrade/r_upgrade.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:system_properties/system_properties.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:open_file/open_file.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
    [DeviceOrientation.portraitUp],
  );
  MobileAds.instance.initialize();

  //Remove this method to stop OneSignal Debugging
  OneSignal.shared.setLogLevel(OSLogLevel.verbose, OSLogLevel.none);

  OneSignal.shared.setAppId("ae9135ea-71ec-4aff-b31a-d9d71ebde556");

// The promptForPushNotificationsWithUserResponse function will show the iOS push notification prompt. We recommend removing the following code and instead using an In-App Message to prompt for notification permission
  OneSignal.shared.promptUserForPushNotificationPermission().then((accepted) {
    print("Accepted permission: $accepted");
  });

  runApp(const MyApp());
}

Future fetchApkLink(String link) async {
  final response = await http.get(
    Uri.parse('https://www.apkmirror.com/' + link),
  );

  if (response.statusCode == 200) {
    var asd = response.body;

    RegExp exp = RegExp(r"((?:<link rel='shortlink' href='\/?\?p=.*?' \/>))");
    Iterable<RegExpMatch> matches = exp.allMatches(asd);

    RegExp expB = RegExp(r"((?:bundle))");
    Iterable<RegExpMatch> matchesB = expB.allMatches(asd);

    var matchedB = "";
    for (var match in matchesB) {
      matchedB = asd.substring(match.start, match.end);
      if (matchedB.toString().trim() == 'bundle') {
        return false;
      }
    }

    var matched = "";
    for (var match in matches) {
      matched = asd.substring(match.start, match.end);
      matched = matched.replaceAll(RegExp("[^0-9]"), '');
    }

    if (matched != "") {
      return "https://www.apkmirror.com/wp-content/themes/APKMirror/download.php?id=" +
          matched;
    } else {
      throw Exception('Failed to get link.');
    }
  } else {
    throw Exception('Failed to get link.');
  }
}

extension MyDateExtension on DateTime {
  DateTime getDateOnly() {
    return DateTime(this.year, this.month, this.day);
  }
}

Future fetchApkmirror(List<String> packageName) async {
  DateTime now = DateTime.now();
  DateTime dateOnly = now.getDateOnly();
  String fileName = "CacheData" + "Apps" + dateOnly.toString() + ".json";
  var cacheDir = await getTemporaryDirectory();

  if (await File(cacheDir.path + "/" + fileName).exists() && false) {
    debugPrint("Loading from cache");
    //TOD0: Reading from the json File
    var jsonData = File(cacheDir.path + "/" + fileName).readAsStringSync();
    // ApiResponse response = ApiResponse.fromJson();
    return json.decode(jsonData);
  } else {
    debugPrint("Loading from API");
    final response = await http.post(
        Uri.parse('https://www.apkmirror.com/wp-json/apkm/v1/app_exists'),
        headers: {
          HttpHeaders.authorizationHeader:
              'Basic YXBpLWFwa3VwZGF0ZXI6cm01cmNmcnVVakt5MDRzTXB5TVBKWFc4',
          HttpHeaders.contentTypeHeader: 'application/json',
          HttpHeaders.cacheControlHeader: 'no-cache',
        },
        body: jsonEncode({"pnames": packageName}));

    if (response.statusCode == 200) {
      var tempDir = await getTemporaryDirectory();

      File file = File(tempDir.path + "/" + fileName);

      file.writeAsString(response.body, flush: true, mode: FileMode.write);
      return (jsonDecode(response.body));
    } else {
      throw Exception('Failed to get Apk');
    }
  }
}

Future<String?> getAbilist() async {
  return await SystemProperties.getSystemProperties("ro.product.cpu.abi");
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
      ],
      title: 'App Updater',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(
        title: 'App Updater',
        platform: platform,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final TargetPlatform? platform;
  const MyHomePage({Key? key, required this.title, this.platform})
      : super(key: key);
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late Future<List<Application>> getApps;
  late List<Application> appsInfo;
  List<_TaskInfo>? _tasks = [];

  Future getAppInfo(List<Application> value) async {
    List<String> packList = [];

    for (var element in value) {
      packList.add(element.packageName.toString());
    }

    var valuee = fetchApkmirror(packList).then((value) async {
      return value;
    });

    return valuee;
  }

  late Future canim;
  late List<Application> apps;
  late Future<bool?> _dataAccept;
  late String abiVersion;
  late String _localPath;
  late bool _permissionReady;
  late InterstitialAd _interstitialAd;
  List oldTasks = [];
  int sdkVer = 63;

  Future<bool?> userDataPopUp() async {
    SharedPreferences _prefs = await SharedPreferences.getInstance();
    bool _dataAccept = false;
    _dataAccept = _prefs.getBool("uDataAccept") ?? false;

    if (_dataAccept == false) {
      return showDialog<bool?>(
        barrierDismissible: false,
        context: context,
        builder: (BuildContext context) => AlertDialog(
          elevation: 0,
          title: const Text('User Data Policy'),
          content: const Text(
              'This app checks the list of "Installed Apps" in device to improve app experience. Package names of installed applications are sent to the remote server and necessary information is obtained. These data are taken anonymously, without keeping any data, without device data and details. Only the package names are checked on the API and the update status is checked inside the device. Package names on the devices are not saved in any where. For now, these data are controlled via the "https://www.apkmirror.com" site. If you want more detailed information, you can send an e-mail to info@xiaomiui.net.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => SystemNavigator.pop(),
              child: const Text(
                'Reject',
                style: TextStyle(color: Colors.red),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _prefs.setBool("uDataAccept", true);
                  Navigator.pop(context, true);
                });
              },
              child: const Text(
                'Accept',
                style: TextStyle(color: Colors.green),
              ),
            ),
          ],
        ),
      );
    } else if (_dataAccept == true) {
      return true;
    } else {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    //first open user data accept
    _dataAccept = userDataPopUp();

    //get abilist cpu
    getAbilist().then((version) {
      setState(() {
        abiVersion = version.toString();
      });
    });

    //get installed apps
    getApps = DeviceApps.getInstalledApplications(
      includeAppIcons: true,
      onlyAppsWithLaunchIntent: true,
    );

    //get installed apps data from api
    canim = getApps.then((value) {
      value
          .sort((a, b) => a.appName.toString().compareTo(b.appName.toString()));
      apps = value;
      return getAppInfo(apps);
    });

    //get android sdk version
    _getAdnroidSDK().then((value) {
      setState(() {
        sdkVer = value;
      });
    });

    _permissionReady = false;

    InterstitialAd.load(
        adUnitId: 'ca-app-pub-3753684966275105/1886941590',
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            // Keep a reference to the ad so you can show it later.
            this._interstitialAd = ad;
          },
          onAdFailedToLoad: (LoadAdError error) {
            print('InterstitialAd failed to load: $error');
          },
        ));
  }

  Future<int> _getAdnroidSDK() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    return androidInfo.version.sdkInt;
  }

  Future<bool> _checkPermission() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    if (widget.platform == TargetPlatform.android &&
        androidInfo.version.sdkInt <= 28) {
      final status = await Permission.storage.status;
      if (status != PermissionStatus.granted) {
        final result = await Permission.storage.request();
        if (result == PermissionStatus.granted) {
          return true;
        }
      } else {
        return true;
      }
    } else {
      return true;
    }
    return false;
  }

  Future<String?> _findLocalPath() async {
    var externalStorageDirPath;
    if (Platform.isAndroid) {
      try {
        externalStorageDirPath = await AndroidPathProvider.downloadsPath;
      } catch (e) {
        final directory = await getExternalStorageDirectory();
        externalStorageDirPath = directory?.path;
      }
    } else if (Platform.isIOS) {
      externalStorageDirPath =
          (await getApplicationDocumentsDirectory()).absolute.path;
    }
    return externalStorageDirPath;
  }

  Future<void> _prepareSaveDir() async {
    _localPath = (await _findLocalPath())!;
    final savedDir = Directory(_localPath);
    bool hasExisted = await savedDir.exists();
    if (!hasExisted) {
      savedDir.create();
    }
  }

  Future<void> _retryRequestPermission() async {
    final hasGranted = await _checkPermission();

    if (hasGranted) {
      await _prepareSaveDir();
    }

    setState(() {
      _permissionReady = hasGranted;
    });
  }

  @override
  void dispose() {
    super.dispose();
    _interstitialAd.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.title,
            style: const TextStyle(
              color: Colors.black,
            )),
      ),
      body: FutureBuilder<bool?>(
          future: _dataAccept,
          builder: (BuildContext context, AsyncSnapshot<bool?> snapshot) {
            if (snapshot.data == true) {
              return homePage();
            }

            return const CircularProgressIndicator();
          }),
    );
  }

  SingleChildScrollView homePage() {
    return SingleChildScrollView(
        child: Column(
      children: [
        FutureBuilder(
            future: canim,
            builder: (BuildContext buildContext, AsyncSnapshot snapshot) {
              if (snapshot.hasData) {
                return ListView.builder(
                  scrollDirection: Axis.vertical,
                  shrinkWrap: true,
                  primary: false,
                  itemCount: snapshot.data['data'].length,
                  itemBuilder: (context, index) {
                    Application app = apps[index];
                    ApplicationWithIcon iconx = app as ApplicationWithIcon;

                    if (_tasks!.length - 1 < index) {
                      _tasks!.add(_TaskInfo(
                          name: app.packageName.toString(), link: null));
                    }

                    List? snapApks = snapshot.data['data'][index]['apks'];
                    List? archs = [];
                    int minapi = 99;
                    int i = 0;
                    int which = 99;
                    if (snapApks != null) {
                      for (var element in snapApks) {
                        archs = element['arches'];
                        minapi = int.parse(element['minapi']);
                        if (minapi > sdkVer) {
                          break;
                        }
                        if (archs!.isNotEmpty) {
                          if (archs.contains(abiVersion.trim()) ||
                              archs.contains('armeabi') ||
                              archs.contains('noarch')) {
                            which = i;
                            break;
                          }
                        } else {
                          which = 0;
                        }
                        i++;
                      }
                    }

                    if (snapshot.data['data'][index]['exists'] == true &&
                        snapshot.data['data'][index]['pname'].toString() !=
                            "com.android.settings") {
                      num str = int.parse(snapshot.data['data'][index]['apks']
                          [0]['version_code']);

                      return Card(
                        elevation: 0,
                        child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 0, horizontal: 20),
                            leading: CircleAvatar(
                              backgroundColor: Colors.transparent,
                              child: Image.memory(app.icon),
                            ),
                            title: Text(app.appName.toString()),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              mainAxisAlignment: MainAxisAlignment.start,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(app.packageName.toString()),
                                snapshot.data['data'][index]['release']
                                                    ['version']
                                                .toString() !=
                                            app.versionName.toString() &&
                                        str.toInt() > app.versionCode.toInt()
                                    ? Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              app.versionName.toString(),
                                              style: const TextStyle(
                                                  color: Colors.red,
                                                  decoration: TextDecoration
                                                      .lineThrough),
                                              softWrap: true,
                                            ),
                                          ),
                                          const Text(" => "),
                                          Expanded(
                                            child: Text(
                                              snapshot.data['data'][index]
                                                      ['release']['version']
                                                  .toString(),
                                              style: const TextStyle(
                                                  color: Colors.green),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        app.versionName.toString(),
                                        style: const TextStyle(
                                          color: Colors.green,
                                        ),
                                        softWrap: true,
                                      ),
                              ],
                            ),
                            trailing: StreamBuilder(
                              stream: RUpgrade.stream,
                              builder: (BuildContext context,
                                  AsyncSnapshot<DownloadInfo> sSnapshot) {
                                if (sSnapshot.hasData &&
                                    sSnapshot.data!.status! ==
                                        DownloadStatus.STATUS_SUCCESSFUL &&
                                    sSnapshot.data!.id ==
                                        _tasks![index].taskId) {
                                  return TextButton(
                                    child: const Text("Install",
                                        style: TextStyle(
                                          color: Colors.white,
                                        )),
                                    onPressed: () async {
                                      await RUpgrade.install(
                                          sSnapshot.data!.id!);
                                    },
                                    style: ButtonStyle(
                                        backgroundColor:
                                            MaterialStateProperty.all(
                                                Colors.orange)),
                                  );
                                } else if (sSnapshot.hasData &&
                                    sSnapshot.data!.percent! < 100 &&
                                    sSnapshot.data!.percent! > 0 &&
                                    sSnapshot.data!.id ==
                                        _tasks![index].taskId) {
                                  return CircularPercentIndicator(
                                    radius: 36.0,
                                    lineWidth: 2.75,
                                    percent: sSnapshot.data!.percent! / 100,
                                    center: IconButton(
                                        padding: const EdgeInsets.all(0.0),
                                        iconSize: 18,
                                        onPressed: () {
                                          setState(() async {
                                            //_cancelDownload(_tasks![index]);
                                            await RUpgrade.cancel(
                                                sSnapshot.data!.id!);
                                          });
                                        },
                                        icon: const Icon(Icons.close)),
                                    backgroundColor: Colors.grey,
                                    progressColor: Colors.green,
                                  );
                                } else {
                                  return which == 99 ||
                                          snapshot.data['data'][index]['app']
                                                  ['name']
                                              .toString()
                                              .contains('fdroid')
                                      ? Text(
                                          AppLocalizations.of(context)!
                                              .no_support,
                                          style: const TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.w600),
                                        )
                                      : snapshot.data['data'][index]['release']
                                                          ['version']
                                                      .toString() !=
                                                  app.versionName.toString() &&
                                              str.toInt() >
                                                  app.versionCode.toInt()
                                          ? TextButton(
                                              child: Text(
                                                  AppLocalizations.of(context)!
                                                      .update,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                  )),
                                              onPressed: () {
                                                try {
                                                  _interstitialAd.show();
                                                } catch (e) {}
                                                modelSheetDownload(context, app,
                                                    snapshot, index, _tasks);
                                              },
                                              style: ButtonStyle(
                                                  backgroundColor:
                                                      MaterialStateProperty.all(
                                                          Colors.green)),
                                            )
                                          : Text(
                                              AppLocalizations.of(context)!
                                                  .no_update,
                                              style: const TextStyle(
                                                  color: Colors.orange,
                                                  fontWeight: FontWeight.w600),
                                            );
                                }
                              },
                            )),
                      );
                    } else {
                      return Container();
                    }
                  },
                );
              }
              return const CircularProgressIndicator();
            }),
      ],
    ));
  }

  Future<dynamic> modelSheetDownload(
      BuildContext context,
      ApplicationWithIcon app,
      AsyncSnapshot<dynamic> snapshot,
      int index,
      List<_TaskInfo>? _tasks) async {
    //debugPrint(_tasks![index].status.toString());

    final directory = await getExternalStorageDirectory();
    String path =
        directory!.path + "/Download/" + app.packageName.toString() + ".apk";
    bool directoryExists = await Directory(path).exists();
    bool fileExists = await File(path).exists();

    return showModalBottomSheet(
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(25), topRight: Radius.circular(25))),
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) {
          return Wrap(
            children: [
              Center(
                child: Column(
                  children: [
                    const SizedBox(
                      height: 20,
                    ),
                    SizedBox(
                      width: 70,
                      height: 5,
                      child: Container(
                        decoration: BoxDecoration(
                            color: const Color(0xffcccccc),
                            borderRadius: BorderRadius.circular(50)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 20, horizontal: 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.transparent,
                                child: Image.memory(
                                  app.icon,
                                ),
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                              Text(app.appName,
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 15),
                          const SizedBox(height: 5),
                          const Divider(),
                          const SizedBox(height: 30),
                          if (snapshot.data['data'][index]['release']
                                  ['whats_new'] !=
                              "") ...[
                            const Text("Changelog",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            Html(
                              data: snapshot.data['data'][index]['release']
                                  ['whats_new'],
                              style: {
                                "p": Style(
                                    margin: const EdgeInsets.only(top: 10),
                                    padding: const EdgeInsets.all(0),
                                    fontSize: const FontSize(15.0),
                                    fontWeight: FontWeight.w400,
                                    color: Colors.grey),
                              },
                            ),
                            const SizedBox(height: 20),
                          ],

                          const Text("File Details",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 20),
                          fileDetailRow("Package name", app.packageName,
                              const Icon(Icons.android)),
                          fileDetailRow("Version Name", app.versionName,
                              const Icon(Icons.vertical_split_rounded)),
                          fileDetailRow(
                              "System App",
                              app.systemApp.toString(),
                              const Icon(Icons
                                  .system_security_update_warning_rounded)),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                    onPressed: () async {
                                      fetchApkLink(snapshot.data['data'][index]
                                              ['apks'][0]['link'])
                                          .then((value) async {
                                        if (value == false) {
                                          Fluttertoast.showToast(
                                              msg:
                                                  "This is a Bundle update. Manual installation is required. We do not support it yet.",
                                              toastLength: Toast.LENGTH_SHORT,
                                              gravity: ToastGravity.CENTER,
                                              fontSize: 16.0);
                                        } else {
                                          _tasks![index].link =
                                              value.toString();

                                          _tasks[index].name =
                                              app.packageName.toString() +
                                                  ".apk".toString();
                                          //await downloadApk(_tasks[index]);
                                          Fluttertoast.showToast(
                                              msg:
                                                  "Download starting, please wait",
                                              toastLength: Toast.LENGTH_SHORT,
                                              gravity: ToastGravity.CENTER,
                                              fontSize: 16.0);
                                          setState(() async {
                                            _tasks[index].taskId =
                                                await RUpgrade.upgrade(
                                              _tasks[index].link!,
                                              fileName: _tasks[index].name,
                                              isAutoRequestInstall: true,
                                            );
                                          });
                                        }
                                      });
                                      Navigator.of(context).pop();
                                      try {
                                        _interstitialAd.show();
                                      } catch (e) {}
                                    },
                                    child: const Text(
                                      'Download Update',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.green),
                                    )),
                              ),
                              if (directoryExists || fileExists) ...[
                                const SizedBox(width: 10),
                                Expanded(
                                    child: OutlinedButton(
                                        onPressed: () async {
                                          try {
                                            _interstitialAd.show();
                                          } catch (e) {}
                                          if (directoryExists || fileExists) {
                                            debugPrint(path.toString());
                                            OpenFile.open(path);
                                          }
                                        },
                                        child: const Text(
                                          'Install update',
                                          textAlign: TextAlign.center,
                                          style:
                                              TextStyle(color: Colors.orange),
                                        ))),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: OutlinedButton(
                                        onPressed: () async {
                                          try {
                                            setState(() async {
                                              final file = File(path);
                                              await file.delete();
                                              Navigator.of(context).pop();
                                              Fluttertoast.showToast(
                                                  msg: "Deleted.",
                                                  toastLength:
                                                      Toast.LENGTH_SHORT,
                                                  gravity: ToastGravity.CENTER,
                                                  fontSize: 16.0);
                                            });
                                          } catch (e) {
                                            return null;
                                          }
                                        },
                                        child: const Text(
                                          'Delete update',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.red),
                                        ))),
                              ],
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        });
  }

  Row fileDetailRow(title, subtitle, icon) {
    var subsub;
    if (subtitle == "false" || subtitle == "true") {
      subsub = Row(
        children: [
          Icon(
            subtitle == "false"
                ? Icons.check_circle_outline
                : Icons.highlight_off,
            size: 18,
            color: subtitle == "false"
                ? Colors.green.shade600
                : Colors.red.shade600,
          ),
          const SizedBox(
            width: 3,
          ),
          Text(
            subtitle == "true" ? "Yes" : "No",
            textAlign: TextAlign.center,
            style: TextStyle(
                color: subtitle == "false"
                    ? Colors.green.shade600
                    : Colors.red.shade600,
                fontSize: 15),
          ),
        ],
      );
    } else {
      subsub = Text(
        subtitle,
        style: const TextStyle(
          fontSize: 15,
          color: Color(0xffa4a4a4),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        icon,
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 3),
              subsub,
              const SizedBox(height: 15)
            ],
          ),
        ),
      ],
    );
  }
}

class _TaskInfo {
  String? name;
  String? link;

  int? taskId;
  int? progress = 0;
  //DownloadTaskStatus? status = DownloadTaskStatus.undefined;

  _TaskInfo({this.name, this.link});
}
