import 'package:app_updater/main.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

Text crtLabel(text) {
  return Text(
    text,
    style: const TextStyle(
        fontSize: 15, fontWeight: FontWeight.w400, color: Color(0xff91919e)),
  );
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    Locale myLocale = Localizations.localeOf(context);
    String dropdownValue = myLocale.toString();

    String langs(value) {
      switch (value.toString()) {
        case 'en':
          return 'English';

        case 'es':
          return 'Español';

        case 'tr':
          return 'Türkçe';

        case 'de':
          return 'Deutsch';

        case 'it':
          return 'Italiano';

        case 'pl':
          return 'Polskie';

        case 'ar':
          return 'العربية';

        case 'ru':
          return 'Pусский';

        case 'pt_pt':
          return 'Português';

        case 'pt_br':
          return 'Portugues do Brasil';

        default:
          return value.toString();
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).backgroundColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              child: Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 5),
                  Text(AppLocalizations.of(context)!.settings,
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w300)),
                  const SizedBox(height: 20),
                  crtLabel(AppLocalizations.of(context)!.general),
                  settingsList(
                    context,
                    Icon(
                      Icons.language,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    Text(AppLocalizations.of(context)!.language),
                    DropdownButton<dynamic>(
                      value: dropdownValue,
                      onChanged: (newValue) {
                        setState(() {
                          MyApp.of(context)!.setLocale(
                              Locale.fromSubtags(languageCode: newValue));

                          dropdownValue = newValue.toString();
                        });
                      },
                      items: <String>['en'].map<DropdownMenuItem>((value) {
                        return DropdownMenuItem(
                          value: value.toString(),
                          child: SizedBox(
                            width: 100,
                            child: Text(
                              langs(value).toString(),
                              overflow: TextOverflow.clip,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  settingsListInk(
                    context,
                    Icon(
                      Icons.dark_mode,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    Text(AppLocalizations.of(context)!.dark_mode),
                    const Icon(
                      Icons.keyboard_arrow_right_rounded,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> darkThemeDialog(BuildContext context) async {
    SharedPreferences _prefs = await SharedPreferences.getInstance();
    String _value = "";
    _value = _prefs.getString("darkAmk") ?? "device";

    return showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.theme),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: const EdgeInsets.all(0),
              title: Text(AppLocalizations.of(context)!.always_light),
              trailing: Radio(
                value: "light",
                groupValue: _value,
                onChanged: (val) {
                  setState(() {
                    _value = val.toString();
                    _prefs.setString("darkAmk", val.toString());
                    MyApp.of(context)!.changeTheme(ThemeMode.light);
                  });
                },
                activeColor: Theme.of(context).colorScheme.secondary,
              ),
            ),
            ListTile(
              contentPadding: const EdgeInsets.all(0),
              title: Text(AppLocalizations.of(context)!.always_dark),
              trailing: Radio(
                value: "dark",
                groupValue: _value,
                onChanged: (val) {
                  setState(() {
                    _value = val.toString();
                    _prefs.setString("darkAmk", val.toString());
                    MyApp.of(context)!.changeTheme(ThemeMode.dark);
                  });
                },
                activeColor: Theme.of(context).colorScheme.secondary,
              ),
            ),
            ListTile(
              contentPadding: const EdgeInsets.all(0),
              title: Text(AppLocalizations.of(context)!.same_dt),
              trailing: Radio(
                value: "device",
                groupValue: _value,
                onChanged: (val) {
                  setState(() {
                    _value = val.toString();
                    _prefs.setString("darkAmk", val.toString());
                    MyApp.of(context)!.changeTheme(ThemeMode.system);
                  });
                },
                activeColor: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Card settingsList(BuildContext context, gleading, gtitle, gtrailing) {
    return Card(
      color: Theme.of(context).backgroundColor,
      elevation: 0,
      child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 0),
          title: gtitle,
          leading: gleading,
          trailing: gtrailing),
    );
  }

  Card settingsListInk(BuildContext context, gleading, gtitle, gtrailing) {
    return Card(
      color: Theme.of(context).backgroundColor,
      elevation: 0,
      child: InkWell(
        onTap: () => darkThemeDialog(context),
        child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 0),
            title: gtitle,
            leading: gleading,
            trailing: gtrailing),
      ),
    );
  }
}
