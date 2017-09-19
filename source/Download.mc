using Toybox.Communications as Comm;
using Toybox.System as Sys;
using Toybox.Lang;
using Toybox.WatchUi as Ui;
using Toybox.Application as App;

class DownloadRequest extends RequestDelegate {
  private var _delegate;

  function initialize(delegate) {
    _delegate = delegate;
    RequestDelegate.initialize();
  }

  function start() {
    var deviceName = Ui.loadResource(Rez.Strings.deviceName);
    if (deviceName.equals("")) {
      deviceName = System.getDeviceSettings().partNumber;
    }

    var url = $.ServerUrl + "/api/mobile/plannedWorkout";
    var params = {
      "appVersion" => AppVersion,
      "device" => deviceName
    };
    var options = {
      :method => Communications.HTTP_REQUEST_METHOD_GET,
      :headers => {
        "Authorization" => "Bearer " + App.getApp().getProperty("access_token")
      },
      :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_FIT
    };
    try {
      Communications.makeWebRequest(url, params, options, method(:handleDownloadResponse));
    } catch (e instanceof Lang.SymbolNotAllowedException) {
      // XXX It would be nice if there was a better way to test for this specific error
      if (e.getErrorMessage().equals("Invalid value for :responseType for this device.")) {
        handleError(Ui.loadResource(Rez.Strings.errorFitNotSupported));
      } else {
        handleError(Ui.loadResource(Rez.Strings.errorUnexpectedDownloadError));
      }
    }
  }

  function handleDownloadResponse(responseCode, downloads) {
    switch (responseCode) {
      case 200:
        var download = downloads.next();
        if (download == null) {
          handleError(Ui.loadResource(Rez.Strings.noWorkoutsString));
        } else {
          handleDownloadedWorkout(download);
        }
        break;
      case 401: // Unauthorized
        Ui.switchToView(new GrantView(true, false), new GrantDelegate(), Ui.SLIDE_IMMEDIATE);
        break;
      case 403: // Forbidden
        handleError(Ui.loadResource(Rez.Strings.errorAccountCapabilities));
        break;
      case 404: // not found
        handleError(Ui.loadResource(Rez.Strings.errorNotFound));
        break;
      default:
        handleError(responseCode);
        break;
    }
  }

  function handleDownloadedWorkout(download) {
    var workoutName = download.getName();
    var workoutIntent = download.toIntent();

    var previousWorkoutName = App.getApp().getProperty("next_workout");
    var updated = previousWorkoutName == null || !previousWorkoutName.equals(workoutName);
    App.getApp().setProperty("next_workout", workoutName);

    Ui.switchToView(new WorkoutView(workoutName, updated), new WorkoutDelegate(workoutIntent), Ui.SLIDE_IMMEDIATE);
  }

}

class DownloadRequestDelegate extends RequestDelegate {

  // Constructor
  function initialize() {
    RequestDelegate.initialize();
  }

  // Handle a successful response from the server
  function handleResponse(data) {
    Ui.switchToView(new DownloadView(), new DownloadDelegate(), Ui.SLIDE_IMMEDIATE);
  }

}
