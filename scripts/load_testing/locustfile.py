import os
import pdb
from random import randint

from faker import Factory
import locust
import pyquery

import foney

fake = Factory.create()
phone_numbers = foney.phone_numbers()

username, password = os.getenv('AUTH_USER'), os.getenv('AUTH_PASS')
auth = (username, password) if username and password else ()

# This should match however many users were created
# for the DB by the rake task.
NUM_USERS = 100


def random_cred():
    """
    Given the rake task:
    rake dev:random_users NUM_USERS=100 SCRYPT_COST='800$8$1$'

    We should have 100 existing users with credentials matching:
    * email address testuser1@example.com through testuser1000@example.com
    * the password "salty pickles"
    * a phone number between +1 (415) 555-0001 and +1 (415) 555-1000.

    This will generate a set of credentials to match one of those entries.
    Note that YOU MUST run the rake task to put these users in the DB first.

    """
    return {
        'email': 'testuser{}@example.com'.format(randint(1, NUM_USERS-1)),
        'password': "salty pickles"
    }


def authenticity_token(dom):
    """
    Retrieves the CSRF auth token from the DOM for submission
    """
    return dom.find('input[name="authenticity_token"]:first').attr('value')


def resp_to_dom(resp):
    """
    Little helper to check response status is 200
    and return the DOM, cause we do that a lot.
    """
    resp.raise_for_status()
    return pyquery.PyQuery(resp.content)


def login(t, credentials):
    """
    Takes a locustTask object and signs you in.
    """
    resp = t.client.get('/', catch_response=True)
    # If you're already logged in, it'll redirect to /account.
    # We need to handle this or you'll get all sorts of downstream failures.
    if '/account' in resp.url:
        print("You're' already logged in. We're going to quit login().")
        return resp

    dom = resp_to_dom(resp)
    token = authenticity_token(dom)

    if not token:
        resp.failure(
            "Not a sign-in page. Current URL is {}.".format(resp.url)
        )

    resp = t.client.post(
        resp.url,
        catch_response=True,
        data={
            'user[email]': credentials['email'],
            'user[password]': credentials['password'],
            'authenticity_token': authenticity_token(dom),
            'commit': 'Submit',
        },
    )
    dom = resp_to_dom(resp)
    code = dom.find("#code").attr('value')

    if not code:
        # if we didn't see the code, then it's probably a failed login
        # due to un-reset credentials.
        # So let's try to rescue with the alternate pass.
        resp = t.client.post(
            resp.url,
            catch_response=True,
            data={
                'user[email]': credentials['email'],
                'user[password]': 'thisisanewpass',
                'authenticity_token': authenticity_token(dom),
                'commit': 'Submit',
            }
        )
        dom = resp_to_dom(resp)
        code = dom.find("#code").attr('value')

        # If we still don't have code, we have a bigger problem.
        if not code:
            resp.failure(
                """
                No 2FA code found after two tries.
                Make sure {} is in the DB.
                """.format(credentials)
            )
            return

    code_form = dom.find("form[action='/login/two_factor/sms']")
    resp = t.client.post(
        code_form.attr('action'),
        data={
            'code': code,
            'authenticity_token': authenticity_token(dom),
            'commit': 'Submit'
        }
    )
    # We're not checking for post-login state here,
    # as it will vary depending on the SP.
    resp.raise_for_status()
    return resp


def logout(t):
    """
    Takes a locustTask object and signs you out.
    Naively assumes the user is actually logged in already.
    """
    resp = t.client.get(
        '/',
        catch_response=True
    )
    dom = resp_to_dom(resp)
    sign_out_link = dom.find('a[href="/api/saml/logout"]').attr('href')

    if not sign_out_link:
        resp.failure("No signout link at {}.".format(resp.url))
        return
    # Authentication is now complete.
    # We've confirmed by the presence of the sign-out link.
    # We can now have the person sign out.
    resp = t.client.get(sign_out_link)
    resp.raise_for_status()


def change_pass(t, password):
    """
    Takes a locustTask and naively expects an already logged in person,
    this navigates to the account (which they should already be on, post-login)
    """
    resp = t.client.get('/account')
    dom = resp_to_dom(resp)
    edit_link = dom.find('a[href="/manage/password"]')

    try:
        resp = t.client.get(edit_link[0].attrib['href'])
    except Exception as error:
        print("""
            There was a problem finding the edit pass link: {}
            You may be hitting an OTP cap with this user,
            or did not run the rake task to generate users.
            Since we can't change the password, we'll exit.
            Here is the content we're seeing at {}: {}
            """.format(error, resp.url, dom('.container').eq(0).text())
              )
        return

    dom = resp_to_dom(resp)
    # To keep it simple for now we're skipping reauthn
    if '/manage/password' in resp.url:
        resp = t.client.post(
            resp.url,
            data={
                'update_user_password_form[password]': password,
                'authenticity_token': authenticity_token(dom),
                '_method': 'patch',
                'commit': 'update'
            }
        )
        resp.raise_for_status()
    else:
        # To-do: handle reauthn case
        print("Failed to find correct page. Currently at {}".format(resp.url))


def signup(t, signup_url=None):
    """
    Creates a new account, starting at the home page,
    then navigating to create account page and submit email

    We're checking for signup_url to pass name and group results
    """
    if signup_url:
        t.client.get(
            signup_url,
            auth=auth,
            name="/sign_up/start?request_id"
        )
    else:
        t.client.get('/sign_up/start', auth=auth)
    resp = t.client.get('/sign_up/enter_email', auth=auth)
    dom = resp_to_dom(resp)

    resp = t.client.post(
        '/sign_up/enter_email',
        data={
            'user[email]': 'test+' + fake.md5() + '@test.com',
            'authenticity_token': authenticity_token(dom),
            'commit': 'Submit',
        },
        auth=auth,
        catch_response=True
    )
    dom = resp_to_dom(resp)

    try:
        link = dom.find("a[href*='confirmation_token']")[0].attrib['href']
    except IndexError:
        if '/account' in resp.url:
            resp.failure(
                """
                Account appears to already be signed up and logged in.
                Current URL: {}.
                """.format(resp.url)
            )
        else:
            resp.failure(
                """
                Failed to get confirmation token.
                Consult https://github.com/18F/identity-idp#load-testing
                and check your application config. Current URL:
                """.format(resp.url)
            )
        return

    # Follow email confirmation link and submit password
    resp = t.client.get(
        link,
        auth=auth,
        name='/sign_up/email/confirm?confirmation_token='
    )
    dom = resp_to_dom(resp)

    token = dom.find('[name="confirmation_token"]')[0].attrib['value']
    data = {
        'password_form[password]': 'salty pickles',
        'authenticity_token': authenticity_token(dom),
        'confirmation_token': token,
        'commit': 'Submit',
    }
    resp = t.client.post(
        '/sign_up/create_password', data=data, auth=auth
    )
    dom = resp_to_dom(resp)

    # visit phone setup page and submit phone number
    resp = t.client.post(
        '/phone_setup',
        data={
            '_method': 'patch',
            'user_phone_form[international_code]': 'US',
            'user_phone_form[phone]': phone_numbers[randint(1, 1000)],
            'user_phone_form[otp_delivery_preference]': 'sms',
            'authenticity_token': authenticity_token(dom),
            'commit': 'Send security code',
        },
        auth=auth,
        catch_response=True
    )
    dom = resp_to_dom(resp)

    try:
        otp_code = dom.find('input[name="code"]')[0].attrib['value']
    except Exception as error:
        resp.failure("""
            There is a problem creating this account: {}.
            Here is the response content: {}
            """.format(error, resp.content))
        return

    # visit security code page and submit pre-filled OTP
    resp = t.client.post(
        '/login/two_factor/sms',
        data={
            'code': otp_code,
            'authenticity_token': authenticity_token(dom),
            'commit': 'Submit',
        },
        auth=auth
    )
    dom = resp_to_dom(resp)

    # click Continue on personal key page
    t.client.post(
        '/sign_up/personal_key',
        data={
            'authenticity_token': authenticity_token(dom),
            'commit': 'Continue',
        },
        auth=auth
    )


class UserBehavior(locust.TaskSet):

    def on_start(self):
        pass

    @locust.task(1)
    def idp_change_pass(self):
        """
        Login, change pass, change it back and logout from IDP.

        This is given a very low weight, since we do not expect
        it to be a common pattern in the real world.
        """
        credentials = random_cred()
        login(self, credentials)

    @locust.task(2)


    @locust.task(2)
    def idp_create_account(self):
        """
        Create an account from within the IDP.

        This is given a low weight because it's not common
        in the real world.
        """
        signup(self)

class WebsiteUser(locust.HttpLocust):
    task_set = UserBehavior
    min_wait = 50
    max_wait = 100
    host = os.getenv('TARGET_HOST') or 'http://localhost:3000'


if __name__ == '__main__':
    WebsiteUser().run()
