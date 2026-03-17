from flask import Flask, render_template, request
import configparser

app = Flask(__name__)

# Default settings

settings = {'title': 'My Website', 'setting1': 'Value1', 'setting2': 'Value2'}

@app.route('/settings', methods=['GET'])
def settings():
    config = configparser.ConfigParser()
    config.read('/home/cantarauk/mysite/settings.ini')
    if 'Settings' in config:
        title = config.get('Settings', 'Title')
        setting1 = config.get('Settings', 'Setting1')
        setting2 = config.get('Settings', 'Setting2')
        return render_template('settings.html', settings=settings, title=title, setting1=setting1, setting2=setting2)
    else:
        return "Error: INI file not found or does not contain [Settings] section."


@app.route('/settings/reset', methods=['POST'])
def reset_settings():
    # Reset settings to default values
    settings['title'] = 'My Website'
    # Save settings to INI file
    save_settings_to_ini(settings['title'])
    return render_template('settings.html', title=settings['title'])

def save_settings_to_ini(title):
    # Save settings to INI file
    config = configparser.ConfigParser()
    config['settings'] = {'title': title}
    with open('/home/cantarauk/mysite/settings.ini', 'w') as configfile:
        config.write(configfile)

@app.route('/settings/save', methods=['POST'])
def save_settings():
    try:
        # Get data from request
        title = request.form['title']
        setting1 = request.form['setting1']
        setting2 = request.form['setting2']

        # Perform saving logic here
        # e.g. save the settings to a database or file

        # Return success response
        response = {
            'message': 'Settings saved successfully!',
            'status': 'success'
        }
        return jsonify(response), 200

    except Exception as e:
        # Return error response
        response = {
            'message': 'Failed to save settings: {}'.format(str(e)),
            'status': 'error'
        }
        return jsonify(response), 500

if __name__ == '__main__':
    app.run(debug=True)

