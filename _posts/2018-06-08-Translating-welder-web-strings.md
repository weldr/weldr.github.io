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

The entire process of translating welder-web is, roughly:

   * The developer marks translatable strings using the tools provided by react-intl
   * During the package build, the translatable strings are extracted to a template file
   * The template file is uploaded to a translation service, in our case [Zanata](https://fedora.zanata.org/)
   * Translators provide translated strings on Zanata
   * Translated strings are downloaded from Zanata and bundled with the rest of welder-web
   * At runtime, welder-web determines the user's preferred language and provides translated versions of strings

As a developer, you do not need to provide any of the actual translations, but there
are some rules to keep in mind in order to make the application possible to translate.

## What to do

Suppose you have something like:

```jsx
{ <button>Edit</button> }
```

The word "Edit" needs to be translated. Wrap the text in a FormattedMessage component, like:

```jsx
import {FormattedMessage} from 'react-intl'
...
{ <button><FormattedMessage defaultMessage="Edit" /></button> }
```

"defaultMessage" is the English string. If you need to provide additional information to the translator,
add a "description" attribute to `<FormattedMessage>`.

`<FormattedMessage>` by default wraps the message in `<span>` tags. If another type of element is needed, use
the "tagName" attribute.

```jsx
{ <option>Debug</option> }
```

could become:

```jsx
{ <FormattedMessage defaultMessage="Debug" tagName="option" /> }
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

react-intl uses the [ICU](https://format-message.github.io/icu-message-format-for-translators/)
format to handle value substitutions. For a string that contains parameters, do something like:

{% raw %}
```jsx
{
  <FormattedMessage
    defaultMessage="Written by {authorName}"
    values={{
      authorName: props.author
    }}
  />
}
```
{% endraw %}

Keep in mind that parameters in the translation can change order. The string
"Origin {origin} of snapshot {name} is not a valid thin LV device" could be
translated as "スナップショット {name} の元 {origin} は有効なシン LV デバイスではありません。".
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
{
  <FormattedMessage
    defaultMessage="The quick {foxColor} fox jumped over the lazy {dogColor} dog."
    values={{
      foxColor: props.foxColor,
      dogColor: props.dogColor
    }}
  />
}
```
{% endraw %}

### Inline markup

Markup elements cannot be sent to translators. Instead, markup should be inserted back
into the string via parameter substitution. Something like:

```jsx
{
  <span><strong>Select components</strong> in this list to add to the blueprint.</span>
}
```

becomes:

{% raw %}
```jsx
{
  <FormattedMessage
    defaultMessage="{selectComponents} in this list to add to the blueprint."
    values={{
      selectComponents: <strong><FormattedMessage defaultMessage="Select components" /></strong>
    }}
  />
}
```
{% endraw %}

### More about ICU

ICU messages also handle localizing the display of numbers and dates, and can handle the issues
surrounding gender and pluralization.

For dates and numbers, just include a type argument as part of the parameter:

{% raw %}
```jsx
{
  <FormattedMessage
    defaultMessage="Number of results from {resultDate, date}: {resultCount, number}"
    values={...}
  />
}
```
{% endraw %}

For sentences that include a quantity, encode the amount in the message itself.

BAD:

{% raw %}
```jsx
{this.days == 1 ? (
  <FormattedMessage defaultMessage="It has been 1 day since the last accident" />
) : (
  <FormattedMessage 
    defaultMessage="It has been {days} days since the last accident"
    values={{days: this.days}}
  />
)}
```
{% endraw %}

GOOD:

{% raw %}
```jsx
{
  <FormattedMessage
    defaultMessage="{days, plural,
      one   {It has been # day since the last accident}
      other {It has been # days since the last accident}
    }"
    values={{
      days: this.days
    }}
  />
}
```
{% endraw %}

This way the translator can modify the sentence as necessary to handle any
language's pluralization rules.

In keeping with the "Bigger is Better" guideline, ICU recommends arranging messages so that
the arguments are the outermost structure, and the sub-messages are complete sentences, as
in the above example.

## What to translate and what not to translate

DO: mark every user-visible string as translatable. This includes blocks of text, titles, tooltips,
popups, etc. Anything that could appear in the browser as an English string should be made
translatable.

DO NOT: translate log messages. Log messages are most often consumed by developers, and
translating them just makes your job harder.
