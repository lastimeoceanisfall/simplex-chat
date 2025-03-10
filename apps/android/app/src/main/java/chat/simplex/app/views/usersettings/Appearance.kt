package chat.simplex.app.views.usersettings

import SectionCustomFooter
import SectionDivider
import SectionItemView
import SectionItemViewSpaceBetween
import SectionItemWithValue
import SectionSpacer
import SectionView
import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_DEFAULT
import android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_ENABLED
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.material.*
import androidx.compose.material.MaterialTheme.colors
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Circle
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.*
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.core.graphics.drawable.toBitmap
import chat.simplex.app.*
import chat.simplex.app.R
import chat.simplex.app.model.ChatModel
import chat.simplex.app.model.SharedPreference
import chat.simplex.app.ui.theme.*
import chat.simplex.app.views.helpers.*
import com.godaddy.android.colorpicker.*
import kotlinx.coroutines.delay
import java.util.*

enum class AppIcon(val resId: Int) {
  DEFAULT(R.mipmap.icon),
  DARK_BLUE(R.mipmap.icon_dark_blue),
}

@Composable
fun AppearanceView(m: ChatModel) {
  val appIcon = remember { mutableStateOf(findEnabledIcon()) }

  fun setAppIcon(newIcon: AppIcon) {
    if (appIcon.value == newIcon) return
    val newComponent = ComponentName(BuildConfig.APPLICATION_ID, "chat.simplex.app.MainActivity_${newIcon.name.lowercase()}")
    val oldComponent = ComponentName(BuildConfig.APPLICATION_ID, "chat.simplex.app.MainActivity_${appIcon.value.name.lowercase()}")
    SimplexApp.context.packageManager.setComponentEnabledSetting(
      newComponent,
      COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP
    )

    SimplexApp.context.packageManager.setComponentEnabledSetting(
      oldComponent,
      PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP
    )

    appIcon.value = newIcon
  }

  AppearanceLayout(
    appIcon,
    m.controller.appPrefs.appLanguage,
    changeIcon = ::setAppIcon,
    editPrimaryColor = { primary ->
      ModalManager.shared.showModalCloseable { close ->
        ColorEditor(primary, close)
      }
    },
  )
}

@Composable fun AppearanceLayout(
  icon: MutableState<AppIcon>,
  languagePref: SharedPreference<String?>,
  changeIcon: (AppIcon) -> Unit,
  editPrimaryColor: (Color) -> Unit,
) {
  Column(
    Modifier.fillMaxWidth(),
    horizontalAlignment = Alignment.Start,
  ) {
    AppBarTitle(stringResource(R.string.appearance_settings))
    SectionView(stringResource(R.string.settings_section_title_language), padding = PaddingValues()) {
      val context = LocalContext.current
//      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
//        SectionItemWithValue(
//          generalGetString(R.string.settings_section_title_language).lowercase().replaceFirstChar { if (it.isLowerCase()) it.titlecase(Locale.US) else it.toString() },
//          remember { mutableStateOf("system") },
//          listOf(ValueTitleDesc("system", generalGetString(R.string.change_verb), "")),
//          onSelected = { openSystemLangPicker(context as? Activity ?: return@SectionItemWithValue) }
//        )
//      } else {
        val state = rememberSaveable { mutableStateOf(languagePref.get() ?: "system") }
        SectionItemView {
          LangSelector(state) {
            state.value = it
            withApi {
              delay(200)
              val activity = context as? Activity
              if (activity != null) {
                if (it == "system") {
                  saveAppLocale(languagePref, activity)
                } else {
                  saveAppLocale(languagePref, activity, it)
                }
              }
            }
          }
        }
//      }
    }
    SectionSpacer()

    SectionView(stringResource(R.string.settings_section_title_icon), padding = PaddingValues(horizontal = DEFAULT_PADDING_HALF)) {
      LazyRow {
        items(AppIcon.values().size, { index -> AppIcon.values()[index] }) { index ->
          val item = AppIcon.values()[index]
          val mipmap = ContextCompat.getDrawable(LocalContext.current, item.resId)!!
          Image(
            bitmap = mipmap.toBitmap().asImageBitmap(),
            contentDescription = "",
            contentScale = ContentScale.Fit,
            modifier = Modifier
              .shadow(if (item == icon.value) 1.dp else 0.dp, ambientColor = colors.secondary)
              .size(70.dp)
              .clickable { changeIcon(item) }
              .padding(10.dp)
          )

          if (index + 1 != AppIcon.values().size) {
            Spacer(Modifier.padding(horizontal = 4.dp))
          }
        }
      }
    }

    SectionSpacer()
    val currentTheme by CurrentColors.collectAsState()
    SectionView(stringResource(R.string.settings_section_title_themes)) {
      SectionItemViewSpaceBetween {
        val darkTheme = isSystemInDarkTheme()
        val state = remember { derivedStateOf { currentTheme.second } }
        ThemeSelector(state) {
          ThemeManager.applyTheme(it.name, darkTheme)
        }
      }
      SectionDivider()
      SectionItemViewSpaceBetween({ editPrimaryColor(currentTheme.first.primary) }) {
        val title = generalGetString(R.string.color_primary)
        Text(title)
        Icon(Icons.Filled.Circle, title, tint = colors.primary)
      }
    }
    if (currentTheme.first.primary != LightColorPalette.primary) {
      SectionCustomFooter(PaddingValues(start = 7.dp, end = 7.dp, top = 5.dp)) {
        TextButton(
          onClick = {
            ThemeManager.saveAndApplyPrimaryColor(LightColorPalette.primary)
          },
        ) {
          Text(generalGetString(R.string.reset_color))
        }
      }
    }
  }
}

@Composable
fun ColorEditor(
  initialColor: Color,
  close: () -> Unit,
) {
  Column(
    Modifier
      .fillMaxWidth()
  ) {
    AppBarTitle(stringResource(R.string.color_primary))
    var currentColor by remember { mutableStateOf(initialColor) }
    ColorPicker(initialColor) {
      currentColor = it
    }

    SectionSpacer()

    TextButton(
      onClick = {
        ThemeManager.saveAndApplyPrimaryColor(currentColor)
        close()
      },
      Modifier.align(Alignment.CenterHorizontally),
      colors = ButtonDefaults.textButtonColors(contentColor = currentColor)
    ) {
      Text(generalGetString(R.string.save_color))
    }
  }
}

@Composable
fun ColorPicker(initialColor: Color, onColorChanged: (Color) -> Unit) {
  ClassicColorPicker(
    color = initialColor,
    modifier = Modifier
      .fillMaxWidth()
      .height(300.dp),
    showAlphaBar = false,
    onColorChanged = { color: HsvColor ->
      onColorChanged(color.toColor())
    }
  )
}

@Composable
private fun LangSelector(state: State<String>, onSelected: (String) -> Unit) {
  // Should be the same as in app/build.gradle's `android.defaultConfig.resConfigs`
  val supportedLanguages = mapOf(
    "system" to generalGetString(R.string.language_system),
    "en" to "English",
    "cs" to "Čeština",
    "de" to "Deutsch",
    "es" to "Español",
    "fr" to "Français",
    "it" to "Italiano",
    "nl" to "Nederlands",
    "ru" to "Русский",
    "zh-CN" to "简体中文"
  )
  val values by remember { mutableStateOf(supportedLanguages.map { it.key to it.value }) }
  ExposedDropDownSettingRow(
    generalGetString(R.string.settings_section_title_language).lowercase().replaceFirstChar { if (it.isLowerCase()) it.titlecase(Locale.US) else it.toString() },
    values,
    state,
    icon = null,
    enabled = remember { mutableStateOf(true) },
    onSelected = onSelected
  )
}

@Composable
private fun ThemeSelector(state: State<DefaultTheme>, onSelected: (DefaultTheme) -> Unit) {
  val darkTheme = isSystemInDarkTheme()
  val values by remember { mutableStateOf(ThemeManager.allThemes(darkTheme).map { it.second to it.third }) }
  ExposedDropDownSettingRow(
    generalGetString(R.string.theme),
    values,
    state,
    icon = null,
    enabled = remember { mutableStateOf(true) },
    onSelected = onSelected
  )
}

//private fun openSystemLangPicker(activity: Activity) {
//  activity.startActivity(Intent(Settings.ACTION_APP_LOCALE_SETTINGS, Uri.parse("package:" + SimplexApp.context.packageName)))
//}

private fun findEnabledIcon(): AppIcon = AppIcon.values().first { icon ->
  SimplexApp.context.packageManager.getComponentEnabledSetting(
    ComponentName(BuildConfig.APPLICATION_ID, "chat.simplex.app.MainActivity_${icon.name.lowercase()}")
  ).let { it == COMPONENT_ENABLED_STATE_DEFAULT || it == COMPONENT_ENABLED_STATE_ENABLED }
}

@Preview(showBackground = true)
@Composable
fun PreviewAppearanceSettings() {
  SimpleXTheme {
    AppearanceLayout(
      icon = remember { mutableStateOf(AppIcon.DARK_BLUE) },
      languagePref = SharedPreference({ null }, {}),
      changeIcon = {},
      editPrimaryColor = {},
    )
  }
}
