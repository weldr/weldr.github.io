---

layout: post
title: "Translating Welder-Web: Writing good strings"
author: dshea
tags: welder-web i18n

---

Making sure we have good translations takes a lot of work during development.
This article is a brief guide for developers on how to handle translations
in the welder-web project.

## The Basics

[welder-web](https://github.com/weldr/welder-web) is built using [React](https://reactjs.org/),
and uses [react-intl](https://github.com/yahoo/react-intl) to handle translations. react-intl
provides a `<IntlProvider>` component, which needs to be the parent of all components with
translatable messages, and a `<FormattedMessage>` component for the strings themselves.

It is up to the developer to mark all translatable strings using the appropriate parts of
react-intl. Once this is done, the English strings are extracted from the
source code and sent to [Zanata](https://fedora.zanata.org/). Translators provide translations
on Zanata, and when welder-web is built these translations are downloaded and bundled as
part of the application.

As a developer, you do not need to provide any of the actual translations, but there
are some rules to keep in mind in order to make the application possible to translate.

## What to do

Suppose you have something like:

```jsx
<button>Edit</button>
```

The word "Edit" needs to be translated. Wrap the text in a FormattedMessage component, like:

```jsx
import {FormattedMessage} from 'react-intl'
...
<button><FormattedMessage defaultMessage="Edit" /></button>
```

"defaultMessage" is the English string. If you need to provide additional information to the translator,
add a "description" attribute to `<FormattedMessage>`.

`<FormattedMessage>` by default wraps the message in `<span>` tags. If another type of element is needed, use
the "tagName" attribute.

```jsx
<option>Debug</option>
```

could become:

```jsx
<FormattedMessage defaultMessage="Debug" tagName="option" />
```

### Attributes

Translating attributes takes a couple of extra steps. For something like:

```jsx
import React from 'react';

class Thingy extends React.Component {
  ...

  render() {
    return (
      <span title="Translatable message"></span>
    );
  }
}

export default Thingy;
```

do something like:

```jsx
import React from 'react';
import {defineMessages, injectIntl, intlShape} from 'react-intl';

const messages = defineMessages({
  translatableMessage: {
    defaultMessage: "Translatable message"
  }
});

class Thingy extends React.Component {
  ...

  render() {
    const { formatMessage } = this.props.intl;
    return (
      <span title={formatMessage(messages.translatableMessage)}></span>
    );
  }
}

Thingy.propTypes = {
  intl: intlShape.isRequired,
};

export default injectIntl(Thingy);
```

### Parameter substitution

react-intl strings use the [ICU](https://format-message.github.io/icu-message-format-for-translators/)
format to handle value substitutions and some other tasks. For a string that contains parameters,
do something like:

{% raw %}
```jsx
<FormattedMessage
  defaultMessage="Written by {authorName}"
  values={{
    authorName: props.author
  }}
/>
```
{% endraw %}

Keep in mind that parameters in the translation can change order. The string
"Origin \"{origin}\" of snapshot \"{name}\" is not a valid thin LV device" could be
translated as "スナップショット \"{name}\" の元 \"{origin}\" は有効なシン LV デバイスではありません。".
Do not rely on word order in the UI.

### Bigger is better

When marking strings for translation, use whole sentences or phrases when possible. Different
languages have different syntax rules, so do not try to piece strings back together from
translated parts.

BAD:

```jsx
"The quick " + props.foxColor " fox jumped over the lazy " + props.dogColor + " dog."
```

GOOD:

{% raw %}
```jsx
<FormattedMessage
  defaultMessage="The quick {foxColor} fox jumped over the lazy {dogColor} dog."
  values={{
    foxColor: props.foxColor,
    dogColor: props.dogColor
  }}
/>
```
{% endraw %}

### Inline markup

Markup elements cannot be sent to translators. Instead, markup should be inserted back
into the string via parameter substitution. Something like:

```jsx
<strong>Select components</strong> in this list to add to the blueprint.
```

becomes:

{% raw %}
```jsx
<FormattedMessage
  defaultMessage="{selectComponents} in this list to add to the blueprint."
  values={{
    selectComponents: <strong><FormattedMessage defaultMessage="Select components" /></strong>
  }}
/>
```
{% endraw %}

### Plurals

Different languages have different rules for pluralization. Quantities should be encoded
using the ICU message format. Something like:

```jsx
{this.days == 1 ? (
  <p>It has been 1 day since the last accident</p>
) : (
  <p>It has been {this.days} days since the last accident</p>
)}
```

becomes:

{% raw %}
```jsx
<p>
  <FormattedMessage
    defaultMessage="{days, plural,
      one   {It has been # day since the last accident}
      other {It has been # days since the last accident}
    }"
    values={{
      days: this.days
    }}
  />
</p>
```
{% endraw %}

## What to translate and what not to translate

DO: mark every user-visible string as translatable. This includes blocks of text, titles, tooltips,
popups, etc. Anything that could appear in your browser as an English string should be made
translatable.

DO NOT: translate log messages. Log messages are most often consumed by developers, and
translating them just makes your job harder.
